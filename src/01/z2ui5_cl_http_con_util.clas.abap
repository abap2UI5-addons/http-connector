CLASS z2ui5_cl_http_con_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_s_http_res,
        body          TYPE string,
        status_code   TYPE i,
        status_reason TYPE string,
      END OF ty_s_http_res.

    CLASS-METHODS http_call
      IMPORTING
        !method       TYPE clike
        body          TYPE clike       OPTIONAL
        !destination  TYPE clike       OPTIONAL
        url           TYPE clike       OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_http_res.

    CLASS-METHODS create_client
      IMPORTING
        !destination  TYPE clike       OPTIONAL
        url           TYPE clike       OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO if_http_client.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_http_con_util IMPLEMENTATION.

  METHOD create_client.

    DATA lv_destination TYPE c LENGTH 32.
    lv_destination = destination.
    DATA(lv_url) = CONV string( url ).

    IF lv_destination IS NOT INITIAL AND lv_destination <> `NONE`.

      CALL METHOD (`CL_HTTP_CLIENT`)=>create_by_destination
        EXPORTING
          destination              = lv_destination
        IMPORTING
          client                   = result
        EXCEPTIONS
          argument_not_found       = 1
          destination_not_found    = 2
          destination_no_authority = 3
          plugin_not_active        = 4
          internal_error           = 5
          OTHERS                   = 6.

    ELSE.

      CALL METHOD (`CL_HTTP_CLIENT`)=>create_by_url
        EXPORTING
          url                = lv_url
        IMPORTING
          client             = result
        EXCEPTIONS
          argument_not_found = 1
          plugin_not_active  = 2
          internal_error     = 3
          OTHERS             = 4.

    ENDIF.

    IF sy-subrc <> 0 OR result IS NOT BOUND.
      RAISE EXCEPTION TYPE z2ui5_cx_util_error
        EXPORTING val = `HTTP_CLIENT_CREATE_ERROR - check the destination/url configuration of the http connector`.
    ENDIF.

  ENDMETHOD.

  METHOD http_call.

    DATA(li_client) = create_client( destination = destination
                                     url         = url ).

    li_client->request->set_method( CONV string( method ) ).
    li_client->request->set_cdata( CONV string( body ) ).

    li_client->send(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        http_invalid_timeout       = 4
        OTHERS                     = 5 ).

    IF sy-subrc = 0.
      li_client->receive(
        EXCEPTIONS
          http_communication_failure = 1
          http_invalid_state         = 2
          http_processing_failed     = 3
          OTHERS                     = 4 ).
    ENDIF.

    IF sy-subrc <> 0.
      li_client->get_last_error( IMPORTING message = DATA(lv_message) ).
      li_client->close( EXCEPTIONS OTHERS = 1 ).
      RAISE EXCEPTION TYPE z2ui5_cx_util_error
        EXPORTING val = |HTTP_COMMUNICATION_ERROR - { lv_message }|.
    ENDIF.

    result-body = li_client->response->get_cdata( ).
    li_client->response->get_status( IMPORTING code   = result-status_code
                                               reason = result-status_reason ).

    li_client->close( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      CLEAR sy-subrc.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
