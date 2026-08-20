CLASS z2ui5_cl_http_con_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

    " replace with your SM59 destination (type G/H) pointing to the source system
    CONSTANTS c_destination TYPE string VALUE `NONE`.
    " alternatively forward directly to an url (only used when c_destination is `NONE`)
    CONSTANTS c_url TYPE string VALUE ``.
    " The consumer node is the endpoint the browser talks to, so the CSRF gate
    " of the framework has to run here - the source system only ever sees the
    " forwarded call, which carries no Origin at all and passes unconditionally.
    " Set to abap_false only if the source system opts out through its own user
    " exit (z2ui5_if_exit~set_config_http_post -> check_csrf_active).
    CONSTANTS c_check_csrf TYPE abap_bool VALUE abap_true.

  PROTECTED SECTION.
  PRIVATE SECTION.

    " client_call( ) carries body and status back, but not the headers of the
    " source system - so the content type is derived from the same three cases
    " the framework itself uses (z2ui5_cl_ui5_http_handler=>set_response): an
    " error body is plain text, a GET answers the HTML shell, every other
    " successful roundtrip is the model JSON. Without it the ICF default
    " (text/html) labels the JSON roundtrip, and an error text - which may
    " quote the app name back - could be rendered as markup.
    CLASS-METHODS get_content_type
      IMPORTING
        !method       TYPE clike
        status_code   TYPE i
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS z2ui5_cl_http_con_handler IMPLEMENTATION.

  METHOD if_http_extension~handle_request.

    DATA ls_res TYPE z2ui5_cl_ui5_util_http=>ty_s_http_res.

    DATA(lo_server) = z2ui5_cl_ui5_util_http=>factory( server ).
    DATA(ls_req) = z2ui5_cl_ui5_http_handler=>get_request( server = server ).

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
          ls_res = z2ui5_cl_ui5_util_http=>client_call( method      = ls_req-method
                                                        body        = ls_req-body
                                                        destination = c_destination
                                                        url         = c_url ).

          " a response without a status line would go out as status 0, which the
          " browser reports as a network error without any readable reason
          IF ls_res-status_code IS INITIAL.
            ls_res = VALUE #( body          = `HTTP_CONNECTOR_ERROR - the source system answered without a status code`
                              status_code   = 502
                              status_reason = `Bad Gateway` ).
          ENDIF.

        CATCH cx_root INTO DATA(lx).
          " The call never reached the source system: destination not maintained
          " or not authorized, host unreachable, timeout. The frontend renders
          " the body of every non-2xx response in its error overlay, so the
          " reason has to travel in it - an uncaught exception here would end in
          " the ICF 500 page, which suppresses exactly that text.
          ls_res = VALUE #( body          = |HTTP_CONNECTOR_ERROR - { lx->get_text( ) }|
                            status_code   = 502
                            status_reason = `Bad Gateway` ).
      ENDTRY.

    ENDIF.

    lo_server->set_cdata( ls_res-body ).
    lo_server->set_header_field( n = `content-type`
                                 v = get_content_type( method      = ls_req-method
                                                       status_code = ls_res-status_code ) ).
    lo_server->set_header_field( n = `cache-control`
                                 v = `no-cache` ).
    lo_server->set_status( code   = ls_res-status_code
                           reason = ls_res-status_reason ).

  ENDMETHOD.

  METHOD get_content_type.

    result = COND #( WHEN status_code >= 400 THEN `text/plain; charset=UTF-8`
                     WHEN method = `GET`     THEN `text/html; charset=UTF-8`
                     ELSE `application/json; charset=UTF-8` ).

  ENDMETHOD.

ENDCLASS.
