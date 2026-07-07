CLASS z2ui5_cl_http_con_server DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_http_con_server IMPLEMENTATION.

  METHOD if_http_extension~handle_request.

    z2ui5_cl_http_handler=>run( server ).

  ENDMETHOD.

ENDCLASS.
