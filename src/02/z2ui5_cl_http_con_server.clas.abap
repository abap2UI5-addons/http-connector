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

    " the source system runs the apps - this node is an ordinary abap2UI5
    " endpoint that happens to be called by the consumer system instead of by
    " a browser
    z2ui5_cl_ui5_http_handler=>run( server ).

  ENDMETHOD.

ENDCLASS.
