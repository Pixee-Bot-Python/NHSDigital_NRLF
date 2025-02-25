# NRLF

## Overview

This project has been given the name `nrlf` which stands for `National Records Locator (Futures)` as a replacement of the existing NRL.

This project uses the `Makefile` to build, test and deploy. This will ensure that a developer can reproduce any operation that the CI/CD pipelines does, meaning they can test the application locally or on their own deployed dev environment.

## Table of Contents

- [Setup](#setup)
- [Getting Started](#getting-started)
- [Deploying](#deploying)
- [Feature Tests](#feature-tests)
- [OAuth Tokens for API request](#oauth-tokens-for-api-requests)
- [Route53 & Hosted Zones](#route53--hosted-zones)
- [Sandbox](#sandbox)
- [Releases](#releases)

## Setup

Before you tackle this guide, there are some more instructions here on the [Developer onboarding guide](https://nhsd-confluence.digital.nhs.uk/pages/viewpage.action?spaceKey=CLP&title=NRLF+-+Developer+Onboarding) in confluence

### 1. Prerequisites

#### 1. ASDF Tool Manager

For an easy way to make sure your local system matches the requirements needed you can use `asdf tool manager`. This tool fetches the required versions of the libraries needed and sets the directory to use that version instead of your system's default version. To get it up and running,

- Install `asdf` using the instructions given here. https://asdf-vm.com/guide/getting-started.html. You can check it installed properly by using the command `asdf --version`
- Install the dependencies using: `$ make asdf-install`
- You should be good to go.

#### 2. If you prefer to get your local machine running manually the requirements are...

- [poetry](https://python-poetry.org/docs/) (this repository uses poetry ^1.5.1)
- [pyenv](https://github.com/pyenv/pyenv) (this repository uses python ^3.9.15)
- jq
- terraform (this repository uses terraform ^1.3.4)
- [tfenv](https://github.com/tfutils/tfenv) (this repository uses terraform 1.3.4)
- coreutils

Swagger generation requirements.

- curl
- java runtime environment (jre) - https://www.oracle.com/java/technologies/downloads/#jdk19-mac
- yq v4

### 2. WSL and PowerShell installation

If you are using Linux machine, please skip this section and go to [Linux set up](#3-linux-set-up)

This section will provide guidance on how to install the latest version of PowerShell and set up the Windows Subsystem for Linux (WSL) on your Windows machine.

PowerShell is a powerful command-line shell and scripting language, while WSL allows you to run a Linux distribution alongside your Windows installation.

If you wish to use the official guidance, links are below:

- PowerShell - https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.3
- WSL - https://learn.microsoft.com/en-us/windows/wsl/install

#### Step 1: Install PowerShell

1. Open a web browser and go to the official PowerShell GitHub releases page: https://github.com/PowerShell/PowerShell/releases.

2. Scroll down to the "Assets" section and find the latest stable release for your system architecture (usually x64 for 64-bit systems). Download the installer package with the "msi" extension.

3. Run the downloaded MSI installer file.

4. Follow the on-screen instructions to install PowerShell. Make sure to select the "Add to PATH" option during installation so that you can easily access PowerShell from the command line.

5. Once the installation is complete, open a new Command Prompt or PowerShell window to verify that PowerShell is installed. You can do this by typing `powershell` and pressing Enter.

#### Step 2: Install Windows Subsystem for Linux (WSL)

1. Open PowerShell as an administrator. To do this, search for "PowerShell" in the Windows Start menu, right-click on "Windows PowerShell," and select "Run as administrator."

2. Run the following command to enable the WSL feature:
   ```shell
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   ```
3. After the feature is enabled, restart your computer by running:
   ```shell
   Restart-Computer
   ```
4. After your computer restarts, open PowerShell as an administrator again and run the following command to download and install a Linux distribution of your choice (e.g., Ubuntu):
   ```shell
   wsl --install
   ```
5. During the installation process, you will be prompted to create a user and set a password for your Linux distribution.

6. Once the installation is complete, you can launch your installed Linux distribution by running:

   ```shell
   wsl
   ```

   To run a specific wsl distribution from within PowerShell or Windows Command Prompt without changing your default distribution:

   use the command: `wsl -d <DistributionName>` , replacing `<DistributionName>` with the name of the distribution you want to use.

#### Step 3: Verify Your Installation

1. To verify that PowerShell and WSL are correctly installed, open a new PowerShell window (WSL not running) and run the following commands:

   Check PowerShell version

   ```shell
   $PSVersionTable.PSVersion
   ```

   Check WSL distribution list

   ```shell
   wsl --list
   ```

   These commands should display the PowerShell version and list the installed WSL distributions.

### 3. Manually setting up Linux

If you're on Linux/WSL and using ASDF, you can skip these steps.

For those on a linux/WSL setup these are some helpful instructions:

- We recommend that you use the NRLF with VSCode and WSL rather than the Spine VM
- There is also a plugin for VSCode called `WSL` which will help you avoid some terminal issues when opening projects in WSL

#### 1. Java:

```shell
sudo apt install default-jre
```

#### 2. Poetry:

```shell
curl -sSL https://install.python-poetry.org | python3
```

```shell
nano ~/.bashrc
```

add to bashrc - spineVM home dir is "/home/spineii-user/"

```shell
export PATH="/$HOME/.local/bin:$PATH"
```

```shell
source ~/.bashrc
```

```shell
poetry --version
```

#### 3. pyenv:

```shell
sudo apt-get update; sudo apt-get install make build-essential libssl-dev zlib1g-dev \
libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
```

```shell
curl https://pyenv.run | bash
```

```shell
nano ~/.bashrc
```

add to bashrc

```shell
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv virtualenv-init -)"
```

```shell
source ~/.bashrc
```

```shell
pyenv --version
```

#### 4. terraform

```shell
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
```

```shell
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
```

```shell
sudo apt update && sudo apt install terraform
```

#### 5. yq:

```shell
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +rx /usr/bin/yq
```

### 4. Install python dependencies

At the root of the repo, run:

```shell
poetry install
poetry shell
make configure
```

NOTE

- You will know if you are correctly in the shell when you see the following before your command line prompt `(nrlf-api-py3.11)` (the version may change based on the version of python)
- If it says (.venv) then you are not using the correct virtual environment
- As mentioned above you at least need Python 3.9 installed globally to run the project, Poetry will handle the rest
- The terraform version can be found in the .terraform-version file at the root

## Getting Started

To build packages:

```
$ make
```

To run the linters over your changes:

```
$ make lint
```

To run the unit tests:

```
$ make test
```

To run the local feature tests:

```
$ make test-features
```

### Troubleshooting

To check your environment:

```
$ make check
```

this will provide a report of the dependencies in your environment and should highlight the things that are not configured correctly or things that are missing.

### Integration testing

For the integration tests, you need to have deployed your infrastructure (using Terraform).

To run integration tests:

```
$ make test-integration
```

To run the Firehose integration tests:

```
$ make test-firehose-integration
```

To run the feature integration tests:

```
$ make test-features-integration
```

### Smoke testing

For smoke tests, you need to have deployed your infrastructure (using Terraform).

Before the first run of the smoke tests, you need to set the required permissions in your deployment. You can do this by running:

```
$ make set-smoketest-perms
```

To run the internal smoke tests against your stack, do this:

```
$ make test-smoke-internal
```

To run the smoke tests against the public access endpoints (via APIGEE proxies), do this:

```
$ make test-smoke-public
```

## API Documentation

If the API changes, the API documentation needs to be updated in the appropriate API repo. This is done by making changes to the API specification `.yaml` files in each repo.

For Consumer API changes, update (NRL Consumer API - consumer.yaml)[https://github.com/NHSDigital/nrl-consumer-api/blob/master/specification/record-locator/consumer.yaml]

For Producer API changes, update (NRL Producer API - producer.yaml)[https://github.com/NHSDigital/nrl-producer-api/blob/master/specification/record-locator/producer.yaml]

Changes to the files in those repos will be reflected when each one is released. See the documentation in each repo for this process.

## Deploying

The NRLF is deployed using terraform. The infrastructure is split into two parts.

All account wide resources like Route 53 hosted zones or IAM roles are found in `terraform/account-wide-infrastructure`

All resources that are not account specific (lambdas, API gateways etc) can be found in `terraform/infrastructure`

Information on deploying these two parts:

- [NRLF main infrastructure](./terraform/infrastructure/README.md)
- [NRLF account wide infrastructure](./terraform/account-wide-infrastructure/README.md)

## Feature tests

Referring to the sample feature test below:

```gherkin
Scenario: Successfully create a Document Pointer of type Mental health crisis plan
   Given {ACTOR TYPE} "{ACTOR}" (Organisation ID "{ORG_ID}") is requesting to {ACTION} Document Pointers
   And {ACTOR TYPE} "{ACTOR}" is registered in the system for application "APP 1" (ID "{APP ID 1}") for document types
     | system                  | value     |
     | http://snomed.info/sct | 736253002 |
   And {ACTOR TYPE} "{ACTOR}" has authorisation headers for application "APP 2" (ID "{APP ID 2}")
   When {ACTOR TYPE} "{ACTOR}" {ACTION} a Document Reference from DOCUMENT template
     | property    | value                          |
     | identifier  | 1234567890                     |
     | type        | 736253002                      |
     | custodian   | {ORG_ID}                       |
     | subject     | 9278693472                     |
     | contentType | application/pdf                |
     | url         | https://example.org/my-doc.pdf |
   Then the operation is {RESULT}
```

The following notes should be made:

1. ACTOR TYPE, ACTOR and ACTION are forced
   to be consistent throughout your test
2. ACTOR TYPE, ACTOR, ACTION, ORG_ID, APP, APP ID, and
   RESULT are enums: their values are
   restricted to a predefined set
3. ACTOR is equivalent to to both custodian
   and organisation
4. The request method (GET, POST, ...) and
   slug (e.g. DocumentReference/\_search) for
   ACTION is taken from the swagger.
5. ”Given ... is requesting to” is mandatory:
   it sets up the base request
6. ”And ... is registered to” sets up a
   org:app:doc-types entry in Auth table
7. ”And ... has authorisation headers” sets up
   authorisation headers

## OAuth tokens for API requests

Clients must provide OAuth access tokens when making requests to the NRLF APIs.

To create an access token for the dev environment, you can do the following:

```
$ make get-access-token
```

To create an access token for another environment:

```
$ make ENV=[env-name] get-access-token
```

Valid `[env-name]` values are `dev`, `int`, `ref` and `prod` for each associated NRLF environment.

Once you have your access token, you provide it as a bearer token in your API requests using the `Authorization` header, like this:

```
Authorization: Bearer <token>
```

If you need to get an API token for the `nrl_sync` application, the command is:

```
$ make ENV=[env-name] APP_ALIAS=nrl_sync get-access-token
```

## Route53 & Hosted Zones

There are 2 parts to the Route53 configuration:

### 1. environment accounts

In `terraform/account-wide-infrastructure/prod/route53.tf`, we have a Hosted Zone:

```terraform
resource "aws_route53_zone" "dev-ns" {
  name = "dev.internal.record-locator.devspineservices.nhs.uk"
}
```

### 2. mgmt account

In `terraform/account-wide-infrastructure/mgmt/route53.tf` we have both a Hosted Zone and a Record per environment:

```terraform
resource "aws_route53_zone" "prodspine" {
  name = "record-locator.spineservices.nhs.uk"

  tags = {
    Environment = terraform.workspace
  }
}

resource "aws_route53_record" "prodspine" {
  zone_id = aws_route53_zone.prodspine.zone_id
  name    = "prod.internal.record-locator.spineservices.nhs.uk"
  records = ["ns-904.awsdns-49.net.",
    "ns-1539.awsdns-00.co.uk.",
    "ns-1398.awsdns-46.org.",
    "ns-300.awsdns-37.com."
  ]
  ttl  = 300
  type = "NS"
}
```

The `records` property is derived by first deploying to a specific environment, in this instance, production, and from the AWS Console navigating to the Route53 Hosted Zone that was just deployed and copying the "Value/Route traffic to" information into the `records` property. Finally, deploy to the mgmt account with the new information.

---

## Sandbox

The public-facing sandbox is an additional persistent workspace (`int-sandbox`) deployed in our INT (`int` / `test`) environment, alongside the persistent workspace named `ref`. It is identical to our live API, except it is open to the world via Apigee (which implements rate limiting on our behalf).

### Sandbox deployment

In order to deploy to a sandbox environment (`dev-sandbox`, `qa-sandbox`, `int-sandbox`) you should use the GitHub Action for persistent environments, where you should select the option to deploy to the sandbox workspace.

### Sandbox database clear and reseed

Any workspace suffixed with `-sandbox` has a small amount of additional infrastructure deployed to clear and reseed the DynamoDB tables (auth and document pointers) using a Lambda running
on a cron schedule that can be found in the `cron/seed_sandbox` directory in the root of this project. The data used to seed the DynamoDB tables can found in the `cron/seed_sandbox/data` directory.

### Sandbox authorisation

The configuration of organisations auth / permissions is dealt with in the "apigee" repos, i.e.

- https://github.com/NHSDigital/record-locator/producer
- https://github.com/NHSDigital/record-locator/consumer

Specifically, the configuration can be found in the file proxies/sandbox/apiproxy/resources/jsc/ConnectionMetadata.SetRequestHeaders.js in these repos.

💡 Developers should make sure that these align between the three repos according to any user journeys that they envisage.

Additionally, and less importantly, there are also fixed organization details in proxies/sandbox/apiproxy/resources/jsc/ClientRPDetailsHeader.SetRequestHeaders.js in these repos.

## Releases

The process to create a new release is as follows:

1. In [Github Releases](https://github.com/NHSDigital/NRLF/releases), press the "Draft new release" button.
2. Press "Choose a tag" and enter the version of the release, say `v3.0.1`. This will be the tag we use to release from.
3. Select `develop` for the release Target
4. Press "Generate release notes" button. This will populate the description with everything that's changed since the last release.
5. Enter the version of the release into the Release Title field, say `v3.0.1`
6. Arrange and update the description to accuruately represent the highlights of the release.
7. Make sure the "Set as the latest release" checkbox it set
8. Press the "Publish release" button to complete the release process

Once your new release has been created, you can then deploy this release through the NRLF environments using the "Persistent Environment Deploy" Github Action.

If the Consumer API has changed, or the documentation for that API has changed, you will also need to release (NRL Consumer API)[https://github.com/NHSDigital/nrl-consumer-api].

If the Producer API has changed, or the documentation for that API has changed, you will also need to release (NRL Producer API)[https://github.com/NHSDigital/nrl-producer-api].

### Deploying releases

Once you have a new release version ready, you can deploy it through our environments as follows:

1. Use the "Persistent Environment Deploy" Github Action workflow to deploy the release tag to `dev`, `dev-sandbox`, `qa`, `qa-sandbox`, `int` and `int-sandbox` environments.
2. If any issues arise in the deployment, fix the issues, create a new release version and start this process again.
3. Once the deployments are complete, use the "Persistent Environment Deploy" Github Action workflow to deploy the release version to `ref`.
4. Once that is complete, use the "Persistent Environment Deploy" workflow to deploy the release version to `prod`.
