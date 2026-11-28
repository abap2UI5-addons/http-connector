CLASS z2ui5_cl_http_con_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

    " replace with your SM59 destination (type G/H) pointing to the source system
    CONSTANTS c_destination TYPE string VALUE `NONE`.
    " alternatively forward directly to a URL (only used when c_destination is `NONE`)
    CONSTANTS c_url TYPE string VALUE ``.
    " The consumer node is the endpoint the browser talks to, so the CSRF gate
    " of the framework has to run here - the source system only ever sees the
    " forwarded call, which carries no Origin at all and passes unconditionally.
    " Set to abap_false only if the source system opts out through its own user
    " exit (z2ui5_if_ui5_exit~set_config_http_post -> check_csrf_active).
    CONSTANTS c_check_csrf TYPE abap_bool VALUE abap_true.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_s_res,
        body          TYPE string,
        status_code   TYPE i,
        status_reason TYPE string,
      END OF ty_s_res.

    " The forwarded call: one request to the source system through
    " cl_http_client, by the SM59 destination or, without one, by c_url. The
    " connector owns it - the framework itself never calls another server, so
    " the core has no HTTP client to borrow. A call that fails comes back as
    " the answer for the browser (get_error_response), never as an exception.
    CLASS-METHODS call_source
      IMPORTING
        !method       TYPE string
        body          TYPE string
        !query        TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_res.

    " The query travels as the browser sent it, never parsed and encoded
    " again. By URL it becomes part of the URL; by destination it is the
    " whole request URI (url is empty then), which the ICF client appends to
    " the path prefix maintained in SM59.
    CLASS-METHODS append_query
      IMPORTING
        url           TYPE string
        !query        TYPE string
      RETURNING
        VALUE(result) TYPE string.

    " The body as text. get_cdata decodes by the charset the response names -
    " without one the ICF falls back to ISO-8859-1 and every UTF-8 multibyte
    " sequence comes back as two or three Latin-1 characters. JSON is UTF-8
    " unless it says otherwise (RFC 8259), so a body without a charset is
    " read as bytes and decoded as UTF-8.
    CLASS-METHODS read_body
      IMPORTING
        io_response   TYPE REF TO if_http_response
      RETURNING
        VALUE(result) TYPE string.

    " The URL parameter that asks the source system for one of the frontend
    " bundles instead of the page (?z2ui5-bundle, ?z2ui5-bundle=cc, ...) -
    " the name z2ui5_cl_ui5_http_handler gives it, which keeps it private.
    CONSTANTS c_bundle_param TYPE string VALUE `z2ui5-bundle`.

    " The response headers of the source system do not come back with the
    " forwarded call - only body and status do - so the consumer node, the
    " endpoint the browser actually talks to, sets them itself, by the rules
    " the framework applies to its own responses
    " (z2ui5_cl_ui5_http_handler->set_response): the content type, the cache
    " policy per verb and the security headers. Without them a roundtrip went
    " out labelled text/html and without nosniff or framing protection. What
    " it cannot reproduce is what the source answers beyond the defaults: the
    " ETag of the page and the bundles, and headers a user exit on the source
    " system adds - see get_security_headers.
    CLASS-METHODS get_header_fields
      IMPORTING
        !method       TYPE clike
        status_code   TYPE i
        t_params      TYPE z2ui5_if_client=>ty_t_name_value OPTIONAL
      RETURNING
        VALUE(result) TYPE z2ui5_if_client=>ty_t_name_value.

    " The cases the framework distinguishes: an error body is plain text (it
    " may quote the app name back - never rendered as markup), a bundle is
    " JavaScript, the page is HTML, every other successful roundtrip is the
    " model JSON.
    CLASS-METHODS get_content_type
      IMPORTING
        !method       TYPE clike
        status_code   TYPE i
        t_params      TYPE z2ui5_if_client=>ty_t_name_value OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

    " The answer when the forwarded call failed. A timeout is told apart:
    " the request reached the source system, which may have carried the
    " action out (the app's main( ) ran, and committed) without answering in
    " time - "could not be reached" invited the user to repeat it. The text
    " names no destination, host or user: every user sees it.
    CLASS-METHODS get_error_response
      IMPORTING
        error_text    TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_res.

    " The security headers every abap2UI5 response carries by default (the
    " t_security_header rows of the shipped user exit). A user exit of the
    " source system cannot reach the browser through the connector: a system
    " that changes these rows there changes them here as well.
    CLASS-METHODS get_security_headers
      RETURNING
        VALUE(result) TYPE z2ui5_if_client=>ty_t_name_value.

ENDCLASS.


CLASS z2ui5_cl_http_con_handler IMPLEMENTATION.

  METHOD if_http_extension~handle_request.

    DATA ls_res TYPE ty_s_res.

    DATA(lo_server) = z2ui5_cl_ui5_util_http=>factory( server ).
    DATA(ls_req) = lo_server->get_req_info( ).

    IF ls_req-method = `POST`
       AND z2ui5_cl_ui5_http_handler=>_check_csrf_rejected(
               active  = c_check_csrf
               origin  = lo_server->get_header_field( `origin` )
               referer = lo_server->get_header_field( `referer` )
               host    = lo_server->get_header_field( `host` ) ) = abap_true.

      ls_res = VALUE #( body          = `CSRF validation failed - cross-origin POST rejected`
                        status_code   = 403
                        status_reason = `Forbidden` ).

    ELSE.

      " the query goes along raw - ?z2ui5-bundle, app_start and every other
      " URL parameter reach the source system as the browser sent them. The
      " path does not: the source answers on its own node.
      ls_res = call_source( method = ls_req-method
                            body   = ls_req-body
                            query  = ls_req-query ).

      " a response without a status line would go out as status 0, which the
      " browser reports as a network error without any readable reason
      IF ls_res-status_code IS INITIAL.
        ls_res = VALUE #( body          = `HTTP_CONNECTOR_ERROR - the source system answered without a status code`
                          status_code   = 502
                          status_reason = `Bad Gateway` ).
      ENDIF.

    ENDIF.

    lo_server->set_cdata( ls_res-body ).
    LOOP AT get_header_fields( method      = ls_req-method
                               status_code = ls_res-status_code
                               t_params    = ls_req-t_params ) INTO DATA(ls_header).
      lo_server->set_header_field( n = ls_header-n
                                   v = ls_header-v ).
    ENDLOOP.
    lo_server->set_status( code   = ls_res-status_code
                           reason = ls_res-status_reason ).

  ENDMETHOD.

  METHOD call_source.

    DATA lo_client TYPE REF TO if_http_client.
    DATA lv_destination TYPE c LENGTH 32.
    DATA lv_message TYPE string.

    " The class is named dynamically, and only here: abaplint's dependency
    " set has the interface if_http_client but not cl_http_client, and
    " everything after the create goes through the interface.
    " A URL is used only without a destination
    DATA(lv_class) = `CL_HTTP_CLIENT`.
    lv_destination = c_destination.
    IF lv_destination IS INITIAL OR lv_destination = `NONE`.
      DATA(lv_url) = append_query( url   = c_url
                                   query = query ).
      CALL METHOD (lv_class)=>create_by_url
        EXPORTING
          url    = lv_url
        IMPORTING
          client = lo_client
        EXCEPTIONS
          OTHERS = 1.
    ELSE.
      CALL METHOD (lv_class)=>create_by_destination
        EXPORTING
          destination = lv_destination
        IMPORTING
          client      = lo_client
        EXCEPTIONS
          OTHERS      = 1.
    ENDIF.
    " destination not maintained or not authorized, no URL - the frontend
    " renders the body of every non-2xx response in its error overlay, so a
    " body has to be there. The reason is for the administrator (SM59, SMICM).
    IF sy-subrc <> 0 OR lo_client IS NOT BOUND.
      result = get_error_response( `` ).
      RETURN.
    ENDIF.

    " no logon popup in a handler: a missing or wrong logon is an error
    lo_client->propertytype_logon_popup = if_http_client=>co_disabled.

    IF lv_destination IS NOT INITIAL AND lv_destination <> `NONE` AND query IS NOT INITIAL.
      lo_client->request->set_header_field( name  = `~request_uri`
                                            value = append_query( url   = ``
                                                                  query = query ) ).
    ENDIF.
    " the roundtrip body is JSON and leaves this system as UTF-8 - without a
    " charset the HTTP client and the source system's ICF fall back to
    " ISO-8859-1, and every character outside Latin-1 the user typed was lost
    " on the way
    IF body IS NOT INITIAL.
      lo_client->request->set_header_field( name  = `content-type`
                                            value = `application/json; charset=utf-8` ).
    ENDIF.
    lo_client->request->set_method( method ).
    lo_client->request->set_cdata( body ).

    lo_client->send( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc = 0.
      lo_client->receive( EXCEPTIONS OTHERS = 1 ).
    ENDIF.
    IF sy-subrc <> 0.
      " host unreachable - or no answer in time, which the text tells apart
      lo_client->get_last_error( IMPORTING message = lv_message ).
      result = get_error_response( lv_message ).
    ELSE.
      result-body = read_body( lo_client->response ).
      lo_client->response->get_status( IMPORTING code   = result-status_code
                                                 reason = result-status_reason ).
    ENDIF.

    " on both paths: the ICM connection would otherwise stay open for the
    " lifetime of the work process. A failed close changes nothing here
    lo_client->close( EXCEPTIONS OTHERS = 0 ).

  ENDMETHOD.

  METHOD append_query.

    result = url.
    DATA(lv_query) = shift_left( val = query
                                 sub = `?` ).
    IF lv_query IS INITIAL.
      RETURN.
    ENDIF.
    IF result CS `?`.
      result = |{ result }&{ lv_query }|.
    ELSE.
      result = |{ result }?{ lv_query }|.
    ENDIF.

  ENDMETHOD.

  METHOD read_body.

    IF to_lower( io_response->get_header_field( `content-type` ) ) CS `charset=`.
      result = io_response->get_cdata( ).
      RETURN.
    ENDIF.

    DATA(lv_bytes) = io_response->get_data( ).
    " named dynamically for the reason call_source gives; bytes that are
    " not UTF-8 after all are left to the ICF
    DATA lo_conv TYPE REF TO object.
    DATA lv_encoding TYPE c LENGTH 20.
    lv_encoding = `UTF-8`.
    DATA(lv_class) = `CL_ABAP_CONV_IN_CE`.
    TRY.
        CALL METHOD (lv_class)=>create
          EXPORTING
            encoding = lv_encoding
          RECEIVING
            conv     = lo_conv.
        CALL METHOD lo_conv->(`CONVERT`)
          EXPORTING
            input = lv_bytes
          IMPORTING
            data  = result.
      CATCH cx_root.
        result = io_response->get_cdata( ).
    ENDTRY.

  ENDMETHOD.

  METHOD get_header_fields.

    result = VALUE #( ( n = `content-type`
                        v = get_content_type( method      = method
                                              status_code = status_code
                                              t_params    = t_params ) ) ).

    " The cache policy of the framework, per verb: the page and the bundles
    " carry no user or app data and may be stored, but are revalidated (with
    " no ETag to send, a revalidation is a full GET). Everything else - the
    " roundtrip data, an error, a HEAD - is never stored.
    IF method = `GET` AND status_code < 300.
      INSERT VALUE #( n = `cache-control`
                      v = `private, no-cache` ) INTO TABLE result.
    ELSE.
      INSERT VALUE #( n = `cache-control`
                      v = `no-cache, no-store, must-revalidate` ) INTO TABLE result.
      INSERT VALUE #( n = `Pragma`
                      v = `no-cache` ) INTO TABLE result.
      INSERT VALUE #( n = `Expires`
                      v = `0` ) INTO TABLE result.
    ENDIF.

    INSERT LINES OF get_security_headers( ) INTO TABLE result.

  ENDMETHOD.

  METHOD get_content_type.

    " the names come lower-cased from the query parser - the framework's own
    " check of the bundle parameter reads them the same way
    result = COND #( WHEN status_code >= 400 THEN `text/plain; charset=UTF-8`
                     WHEN method <> `GET`    THEN `application/json; charset=UTF-8`
                     WHEN line_exists( t_params[ n = c_bundle_param ] ) "#EC CI_SORTSEQ
                                             THEN `application/javascript; charset=UTF-8`
                     ELSE `text/html; charset=UTF-8` ).

  ENDMETHOD.

  METHOD get_error_response.

    " the text of the HTTP client's last error (HTTP_COMMUNICATION_ERROR -
    " ..., cx_web_http_client_error) - CS ignores the case
    IF error_text CS `timeout` OR error_text CS `timed out` OR error_text CS `time out`.
      result = VALUE #( body          = `HTTP_CONNECTOR_ERROR - the source system did not answer in time - ` &&
                                        `the action may have been carried out there, check before you repeat it`
                        status_code   = 504
                        status_reason = `Gateway Timeout` ).
    ELSE.
      result = VALUE #( body          = `HTTP_CONNECTOR_ERROR - the source system could not be reached`
                        status_code   = 502
                        status_reason = `Bad Gateway` ).
    ENDIF.

  ENDMETHOD.

  METHOD get_security_headers.

    result = VALUE #(
        ( n = `X-Content-Type-Options`       v = `nosniff` )
        ( n = `X-Frame-Options`              v = `SAMEORIGIN` )
        ( n = `Referrer-Policy`              v = `strict-origin-when-cross-origin` )
        ( n = `Permissions-Policy`           v = `geolocation=(self), microphone=(self), camera=(self), payment=(), usb=()` )
        ( n = `Cross-Origin-Resource-Policy` v = `same-origin` ) ).

  ENDMETHOD.

ENDCLASS.
