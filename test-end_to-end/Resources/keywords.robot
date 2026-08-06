*** Settings ***
Library    SeleniumLibrary
Resource   ../resources/locators.robot

*** Variables ***
${LOGIN_URL}         https://fr.openfoodfacts.org

${VALID_EMAIL}       validEmail@gmail.com
${VALID_PASSWORD}    validPassword
${INVALID_EMAIL}     invalid@example.com
${INVALID_PASSWORD}  WrongPass
${BROWSER}          Chrome

*** Keywords ***
Open Login Page
    Open Browser    ${LOGIN_URL}    ${BROWSER}
    Maximize Browser Window
    Click Element   ${CONEXION_Button}


Enter Credentials
    [Arguments]    ${email}    ${password}
    Input Text     ${EMAIL_FIELD}    ${email}
    Input Text     ${PASSWORD_FIELD}    ${password}
    Click Element  ${LOGIN_BUTTON}

Verify Login Success
    Wait Until Element Is Visible    ${LOGGED_IN_ELEMENT}    timeout=5s


Verify Login Failure
    Wait Until Element Is Visible    ${ERROR_MESSAGE}    timeout=5s


Close Browser Session
    Close Browser
