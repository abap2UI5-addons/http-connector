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

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_http_con_handler IMPLEMENTATION.

  METHOD if_http_extension~handle_request.

    DATA(ls_req) = z2ui5_cl_http_handler=>get_request( server = server ).

    DATA(ls_res) = z2ui5_cl_http_con_util=>http_call( method      = ls_req-method
                                                      body        = ls_req-body
                                                      destination = c_destination
                                                      url         = c_url ).

    DATA(lo_server) = z2ui5_cl_util_http=>factory( server ).
    lo_server->set_cdata( ls_res-body ).
    lo_server->set_header_field( n = `cache-control`
                                 v = `no-cache` ).
    lo_server->set_status( code   = ls_res-status_code
                           reason = ls_res-status_reason ).

  ENDMETHOD.

ENDCLASS.
