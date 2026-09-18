*** Variables ***
${CONEXION_Button}    xpath=(//a[@class='round button secondary'])[1]
${EMAIL_FIELD}        xpath=(//input[@id='login_user_id'])[1]
${PASSWORD_FIELD}     xpath=(//input[@id='login_user_password'])[1]
${LOGIN_BUTTON}       xpath=(//input[@id='submit'])[1]
${ERROR_MESSAGE}      xpath=(//h1[normalize-space()='Erreur'])[1]
${LOGGED_IN_ELEMENT}  xpath=(//a[@class='userlink h-space-tiny'])[1]