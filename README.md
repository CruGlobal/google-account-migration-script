## requirements

You must have a modern (2.1+) version of ruby and the chromedriver installed on your path (https://github.com/SeleniumHQ/selenium/wiki/ChromeDriver). Try `brew install chromedriver`.

You must also copy the `config.json` file (which you can get from Mark K. or Shelby B.) into the root of this project.

## install

`bundle install`

## setup and permissions
Before you run the script, you will need to create key_login.rb, config.json, and config.yml. Copy the respective example files and follow the configuration/setup as follows:

### key_login.rb

You will need to add your okta/key username and password to this file in the respective placeholders.

### config.json

To enable access to google sheets, you will need to include the `cliend_id` and the `client_secret` from the google cloud services. If for some reason Mark K or Shelby B is unavailable to give you these you will need access to [google cloud services](https://console.cloud.google.com/). Someone will need to add you to the "automated google migration" project. From there you can navigate to
> api's and services -> credentials -> click on "google drive ruby" (under OAuth 2.0 Client IDs)

You will also need to remove the refresh_token line. The google_drive gem will then tell you what to do, but you must remove the refresh_token for this to happen.

### config.yml

This outlines how the script is going to interact and iterate over the data in the google sheet of interest. 
- the spreadsheet key will come from the URL of the sheet in question
- the spreadsheet index refers to a specific tab of the sheet, and is zero-based
- start_row_number and end_row_number indicate starting and ending rows (one-based)
- to get an okta token you will need to reach out to jason buckner and ask for okta admin priveleges. Once acquired, go to [okta admin api token page](https://signon-admin.okta.com/admin/access/api/tokens) and just create a token with your name. Then copy/paste as the value for okta_token.

## running

`ruby auto.rb`

The first time you run this you'll receive some prompts to fill in a key. Follow the instructions.
You may also need to allow chromedriver to run from System Preferences / Security & Privacy / General

This will run one dry run against one row. Once you are comfortable, you can turn off the dry_run and only_one booleans inside the `auto.rb` file.

## troubleshooting

If you have issues remove the refresh_token from config.json and try running again. The refresh_token expires about every 6 months and will need to be removed so the gem can replace it.
