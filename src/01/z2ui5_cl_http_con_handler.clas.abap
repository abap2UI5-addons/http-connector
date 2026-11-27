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
        VALUE(result) TYPE z2ui5_cl_ui5_util_http=>ty_s_http_res.

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

    DATA ls_res TYPE z2ui5_cl_ui5_util_http=>ty_s_http_res.
    DATA ls_call TYPE z2ui5_cl_ui5_util_http=>ty_s_client_req.

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

      TRY.
          " the query goes along raw - ?z2ui5-bundle, app_start and every
          " other URL parameter reach the source system as the browser sent
          " them. The path does not: the source answers on its own node.
          " A URL is used only without a destination; next to one it would
          " be read as the path below it
          ls_call = VALUE #( method      = ls_req-method
                             body        = ls_req-body
                             destination = c_destination
                             query       = ls_req-query ).
          IF c_destination IS INITIAL OR c_destination = `NONE`.
            ls_call-url = c_url.
          ENDIF.
          " the roundtrip body is JSON and leaves this system as UTF-8 - without
          " a charset the HTTP client and the source system's ICF fall back to
          " ISO-8859-1, and every character outside Latin-1 the user typed was
          " lost on the way
          IF ls_call-body IS NOT INITIAL.
            ls_call-t_header = VALUE #( ( n = `content-type`
                                          v = `application/json; charset=utf-8` ) ).
          ENDIF.
          ls_res = z2ui5_cl_ui5_util_http=>client_request( ls_call ).

          " a response without a status line would go out as status 0, which the
          " browser reports as a network error without any readable reason
          IF ls_res-status_code IS INITIAL.
            ls_res = VALUE #( body          = `HTTP_CONNECTOR_ERROR - the source system answered without a status code`
                              status_code   = 502
                              status_reason = `Bad Gateway` ).
          ENDIF.

        CATCH cx_root INTO DATA(lx_call).
          " The call failed: destination not maintained or not authorized,
          " host unreachable - or no answer in time. The frontend renders
          " the body of every non-2xx response in its error overlay, so a body
          " has to be there - an uncaught exception would end in the ICF 500
          " page. The reason is for the administrator (SM59, SMICM).
          ls_res = get_error_response( lx_call->get_text( ) ).
      ENDTRY.

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
