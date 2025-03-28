*** Settings ***
Library    SeleniumLibrary
Library    OperatingSystem
Resource   ../resources/keywords.robot
Test Teardown    Run Keyword If    '${TEST STATUS}' == 'FAIL'    Capture Page Screenshot    output/erreur-${TEST NAME}.png

*** Test Cases ***
Nettoyer Avant Test
    Remove File    output/log.html
    Remove File    output/report.html
    Remove File    output/output.xml
    Remove File    output/screenshot.png  # Supprime un fichier précis


Test Login With Valid Credentials
    Open Login Page
    Enter Credentials    ${VALID_EMAIL}    ${VALID_PASSWORD}
    Verify Login Success
    Close Browser Session


Test Login With Invalid Email
    Open Login Page
    Enter Credentials    ${INVALID_EMAIL}    ${VALID_PASSWORD}
    Verify Login Failure
    Close Browser Session

Test Login With Invalid Password
    Open Login Page
    Enter Credentials    ${VALID_EMAIL}    ${INVALID_PASSWORD}
    Verify Login Failure
    Close Browser Session

Test Login With Empty Fields
    Open Login Page
    Enter Credentials    ${EMPTY}    ${EMPTY}
    Wait Until Page Contains    Se connecter    timeout=2s
    ${email_vide} =    Run Keyword And Return Status    Element Attribute Should Be    ${email}    value    ${EMPTY}
    Run Keyword If    ${email_vide}    Log    ✅ Le champ email est vide
    Close Browser Session



