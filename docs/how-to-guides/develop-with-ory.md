# Developing with Ory

Here is how to develop with Ory


**Current branch is OryAuth-get-cookies**

All Ory configuration files are in the Ory folder

- kratosauth.yml is the docker configuration with kratos
- kratos.yml is used to configure kratos
- identity.schema.json is used to configure the identity schema such as requiring username, email, etc. 
- hydraauth.yml and hydra.yml are for configuring hydra

## Start up Ory Kratos container
- Add Ory/kratosauth.yml to COMPOSE_FILE variable in .env file
- Run Make Dev

## Ory Managed UI 
This is useful for seeing if a current user is signed in and seeing the current users info

http://kratos.openfoodfacts.localhost:4455/welcome is the managed UI

From here you can login, sign up, recover account, verify account, and change account setting. 

## Signing in and Creating an Account
There are currently two ways to sign in and and create and account. <br/>

Ory Manged UI: Go to http://kratos.openfoodfacts.localhost:4455/welcome <br/>

OFF Page: set $ORY_ENABLED to 1 in user.pl which will let you click create an account on the OFF page redirecting you to http://kratos.openfoodfacts.localhost:4455/registration, to sign in from OFF page you have to click create an account then sign in as there is no button currently to redirect to sign in.

- After completing login and sign up flows you will be redirected to world.openfoodfacts.localhost/cgi/kratos_auth.pl
- kratos_auth.pl retrieves the ory_kratos_session cookie, does a HTTP Get request to http://kratos.openfoodfacts.localhost:4433/sessions/whoami and responds with JSON information of the current user
- The JSON is used to create hash that will create a new sto file if the user does not already have one. <br/>
To see the users sto file run following commands: 
  - launch docker-compose run --rm backend re.pl
  - use ProductOpener::Store qw/:all/;
  - my $user_id= "xxxxx" (<- put user ID)
  - my $user_ref = retrieve("/mnt/podata/users/$user_id.sto")
- The user will then be given a session with the open_user_session() function and be redirected back to openfoodfacts.localhost, you can see the session in sto file with above commands
- **OFF still does not display that the user is signed in, but creating sessions for users in kratos_auth.pl works**

## Logging Out
Currently to logout go to world.openfoodfacts.localhost/cgi/kratos_logout.pl, eventually need to make logout button redirect to world.openfoodfacts.localhost/cgi/kratos_logout.pl

- kratos_logout.pl will do a get request to http://kratos.openfoodfacts.localhost:4433/self-service/logout/browser getting a logout url for kratos
- Unset OFF cookie
- Redirecting to given logout url
- Kratos knows where to go after redirecting from logout url as this is configured in kratos.yml

## Account Settings
Currently can only be done in Ory Managed UI, but eventually can simply redirect account settings button to http://kratos.openfoodfacts.localhost:4455/settings

What should be done:
- After completing the settings flow update the users sto file with new kratos JSON parameters

Can configure where to go after settings flow is complete in kratos.yml

## Account recovery and Email verification 
Will configure with the OFF courier see the docs https://www.ory.sh/docs/kratos/guides/account-activation-email-verification







