CLASS ltcl_test DEFINITION DEFERRED.
CLASS z2ui5_cl_http_con_handler DEFINITION LOCAL FRIENDS ltcl_test.

CLASS ltcl_test DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    METHODS test_error_is_text   FOR TESTING RAISING cx_static_check.
    METHODS test_get_is_html     FOR TESTING RAISING cx_static_check.
    METHODS test_post_is_json    FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_test IMPLEMENTATION.

  METHOD test_error_is_text.

    " an error body may quote the app name back - never rendered as markup
    cl_abap_unit_assert=>assert_equals(
        exp = `text/plain; charset=UTF-8`
        act = z2ui5_cl_http_con_handler=>get_content_type( method      = `GET`
                                                           status_code = 502 ) ).

    cl_abap_unit_assert=>assert_equals(
        exp = `text/plain; charset=UTF-8`
        act = z2ui5_cl_http_con_handler=>get_content_type( method      = `POST`
                                                           status_code = 403 ) ).

  ENDMETHOD.

  METHOD test_get_is_html.

    cl_abap_unit_assert=>assert_equals(
        exp = `text/html; charset=UTF-8`
        act = z2ui5_cl_http_con_handler=>get_content_type( method      = `GET`
                                                           status_code = 200 ) ).

  ENDMETHOD.

  METHOD test_post_is_json.

    cl_abap_unit_assert=>assert_equals(
        exp = `application/json; charset=UTF-8`
        act = z2ui5_cl_http_con_handler=>get_content_type( method      = `POST`
                                                           status_code = 200 ) ).

  ENDMETHOD.

ENDCLASS.
