CLASS ltcl_test DEFINITION DEFERRED.
CLASS z2ui5_cl_http_con_handler DEFINITION LOCAL FRIENDS ltcl_test.

CLASS ltcl_test DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    METHODS test_error_is_text   FOR TESTING RAISING cx_static_check.
    METHODS test_get_is_html     FOR TESTING RAISING cx_static_check.
    METHODS test_post_is_json    FOR TESTING RAISING cx_static_check.
    METHODS test_bundle_is_js    FOR TESTING RAISING cx_static_check.
    METHODS test_post_no_store   FOR TESTING RAISING cx_static_check.
    METHODS test_get_revalidated FOR TESTING RAISING cx_static_check.
    METHODS test_error_no_store  FOR TESTING RAISING cx_static_check.
    METHODS test_security_header FOR TESTING RAISING cx_static_check.
    METHODS test_timeout_is_504  FOR TESTING RAISING cx_static_check.

    "! the value of header field name in the headers of a response, or
    "! `MISSING` when the response has no such field
    METHODS header_value
      IMPORTING
        !method       TYPE clike
        status_code   TYPE i
        name          TYPE string
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS ltcl_test IMPLEMENTATION.

  METHOD header_value.

    DATA lt_header TYPE z2ui5_if_client=>ty_t_name_value.
    DATA ls_header LIKE LINE OF lt_header.
    lt_header = z2ui5_cl_http_con_handler=>get_header_fields( method      = method
                                                                    status_code = status_code ).
    result = `MISSING`.

    LOOP AT lt_header INTO ls_header WHERE n = name.
      result = ls_header-v.
    ENDLOOP.

  ENDMETHOD.

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
    DATA temp1 TYPE z2ui5_if_client=>ty_t_name_value.
    DATA temp2 LIKE LINE OF temp1.

    cl_abap_unit_assert=>assert_equals(
        exp = `text/html; charset=UTF-8`
        act = z2ui5_cl_http_con_handler=>get_content_type( method      = `GET`
                                                           status_code = 200 ) ).

    " another URL parameter does not make the page a bundle

    CLEAR temp1.

    temp2-n = `app_start`.
    temp2-v = `z2ui5_cl_app_hello_world`.
    INSERT temp2 INTO TABLE temp1.
    cl_abap_unit_assert=>assert_equals(
        exp = `text/html; charset=UTF-8`
        act = z2ui5_cl_http_con_handler=>get_content_type(
                  method      = `GET`
                  status_code = 200
                  t_params    = temp1 ) ).

  ENDMETHOD.

  METHOD test_post_is_json.

    cl_abap_unit_assert=>assert_equals(
        exp = `application/json; charset=UTF-8`
        act = z2ui5_cl_http_con_handler=>get_content_type( method      = `POST`
                                                           status_code = 200 ) ).

  ENDMETHOD.

  METHOD test_bundle_is_js.

    " ?z2ui5-bundle, with or without a value, answers a script, not the page
    DATA temp3 TYPE z2ui5_if_client=>ty_t_name_value.
    DATA temp4 LIKE LINE OF temp3.
    DATA temp5 TYPE z2ui5_if_client=>ty_t_name_value.
    DATA temp6 LIKE LINE OF temp5.
    DATA temp7 TYPE z2ui5_if_client=>ty_t_name_value.
    DATA temp8 LIKE LINE OF temp7.
    CLEAR temp3.

    temp4-n = `z2ui5-bundle`.
    INSERT temp4 INTO TABLE temp3.
    cl_abap_unit_assert=>assert_equals(
        exp = `application/javascript; charset=UTF-8`
        act = z2ui5_cl_http_con_handler=>get_content_type(
                  method      = `GET`
                  status_code = 200
                  t_params    = temp3 ) ).


    CLEAR temp5.

    temp6-n = `z2ui5-bundle`.
    temp6-v = `cc`.
    INSERT temp6 INTO TABLE temp5.
    temp6-n = `z2ui5-version`.
    temp6-v = `0123abcd`.
    INSERT temp6 INTO TABLE temp5.
    cl_abap_unit_assert=>assert_equals(
        exp = `application/javascript; charset=UTF-8`
        act = z2ui5_cl_http_con_handler=>get_content_type(
                  method      = `GET`
                  status_code = 200
                  t_params    = temp5 ) ).

    " a failed bundle request is still an error text

    CLEAR temp7.

    temp8-n = `z2ui5-bundle`.
    INSERT temp8 INTO TABLE temp7.
    cl_abap_unit_assert=>assert_equals(
        exp = `text/plain; charset=UTF-8`
        act = z2ui5_cl_http_con_handler=>get_content_type(
                  method      = `GET`
                  status_code = 500
                  t_params    = temp7 ) ).

  ENDMETHOD.

  METHOD test_post_no_store.

    " the roundtrip carries the app's data - never stored
    cl_abap_unit_assert=>assert_equals(
        exp = `no-cache, no-store, must-revalidate`
        act = header_value( method      = `POST`
                            status_code = 200
                            name        = `cache-control` ) ).

    cl_abap_unit_assert=>assert_equals(
        exp = `no-cache, no-store, must-revalidate`
        act = header_value( method      = `HEAD`
                            status_code = 200
                            name        = `cache-control` ) ).

  ENDMETHOD.

  METHOD test_get_revalidated.

    cl_abap_unit_assert=>assert_equals(
        exp = `private, no-cache`
        act = header_value( method      = `GET`
                            status_code = 200
                            name        = `cache-control` ) ).

  ENDMETHOD.

  METHOD test_error_no_store.

    " an error must not be revalidated into staying
    cl_abap_unit_assert=>assert_equals(
        exp = `no-cache, no-store, must-revalidate`
        act = header_value( method      = `GET`
                            status_code = 502
                            name        = `cache-control` ) ).

  ENDMETHOD.

  METHOD test_security_header.

    cl_abap_unit_assert=>assert_equals(
        exp = `nosniff`
        act = header_value( method      = `POST`
                            status_code = 200
                            name        = `X-Content-Type-Options` ) ).

    cl_abap_unit_assert=>assert_equals(
        exp = `SAMEORIGIN`
        act = header_value( method      = `GET`
                            status_code = 502
                            name        = `X-Frame-Options` ) ).

  ENDMETHOD.

  METHOD test_timeout_is_504.

    " a timeout reached the source system - the action may have run there
    DATA ls_res TYPE z2ui5_cl_ui5_util_http=>ty_s_http_res.
    ls_res = z2ui5_cl_http_con_handler=>get_error_response(
                       `HTTP_COMMUNICATION_ERROR - ICM_HTTP_TIMEOUT: Connection timed out` ).
    cl_abap_unit_assert=>assert_equals( exp = 504
                                        act = ls_res-status_code ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*did not answer in time*may have been carried out*`
                                         act = ls_res-body ).

    " anything else never got there
    ls_res = z2ui5_cl_http_con_handler=>get_error_response( `HTTP_COMMUNICATION_ERROR - connection refused` ).
    cl_abap_unit_assert=>assert_equals( exp = 502
                                        act = ls_res-status_code ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*could not be reached`
                                         act = ls_res-body ).

  ENDMETHOD.

ENDCLASS.
