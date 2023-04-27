Feature: Producer Create Failure Scenarios

  Background:
    Given template DOCUMENT
      """
      {
        "resourceType": "DocumentReference",
        "id": "$producer_id-$identifier",
        "custodian": {
          "identifier": {
            "system": "https://fhir.nhs.uk/Id/ods-organization-code",
            "value": "$custodian"
          }
        },
        "subject": {
          "identifier": {
            "system": "$system",
            "value": "$subject"
          }
        },
        "type": {
          "coding": [
            {
              "system": "http://snomed.info/sct",
              "code": "$type"
            }
          ]
        },
        "content": [
          {
            "attachment": {
              "contentType": "$contentType",
              "url": "$url"
            }
          }
        ],
        "status": "current"
      }
      """
    And template BAD_DOCUMENT
      """
      {
        "resourceType": "DocumentReference",
        "id": "$producer_id-$identifier",
        "subject": {
          "identifier": {
            "system": "https://fhir.nhs.uk/Id/nhs-number",
            "value": "$subject"
          }
        },
        "type": {
          "coding": [
            {
              "system": "http://snomed.info/sct",
              "code": "$type"
            }
          ]
        },
        "content": [
          {
            "attachment": {
              "contentType": "$contentType",
              "url": "$url"
            }
          }
        ],
        "status": "current"
      }
      """
    And template DUPLICATE_FIELDS
      """
      {
        "resourceType": "DocumentReference",
        "id": "$producer_id-$identifier",
        "subject": {
          "identifier": {
            "system": "https://fhir.nhs.uk/Id/nhs-number",
            "value": "$subject"
          }
        },
        "type": {
          "coding": [
            {
              "system": "http://snomed.info/sct",
              "code": "$type"
            }
          ]
        },
        "content": [
          {
            "attachment": {
              "contentType": "$contentType",
              "url": "$url"
            }
          }
        ],
        "status": "current"
      }
      """
    And template DOCUMENT_WITH_INVALID_ID_FORMAT
      """
      {
        "resourceType": "DocumentReference",
        "id": "$custodian|$identifier",
        "custodian": {
          "identifier": {
            "system": "https://fhir.nhs.uk/Id/ods-organization-code",
            "value": "$custodian"
          }
        },
        "subject": {
          "identifier": {
            "system": "https://fhir.nhs.uk/Id/nhs-number",
            "value": "$subject"
          }
        },
        "type": {
          "coding": [
            {
              "system": "http://snomed.info/sct",
              "code": "$type"
            }
          ]
        },
        "content": [
          {
            "attachment": {
              "contentType": "$contentType",
              "url": "$url"
            }
          }
        ],
        "status": "current"
      }
      """
    And template DOCUMENT_WITH_INVALID_CUSTODIAN_SYSTEM
      """
      {
        "resourceType": "DocumentReference",
        "id": "$custodian|$identifier",
        "custodian": {
          "identifier": {
            "system": "https://test-system/Id/ods-organization-code",
            "value": "$custodian"
          }
        },
        "subject": {
          "identifier": {
            "system": "https://fhir.nhs.uk/Id/nhs-number",
            "value": "$subject"
          }
        },
        "type": {
          "coding": [
            {
              "system": "http://snomed.info/sct",
              "code": "$type"
            }
          ]
        },
        "content": [
          {
            "attachment": {
              "contentType": "$contentType",
              "url": "$url"
            }
          }
        ],
        "status": "current"
      }
      """
    And template OUTCOME
      """
      {
        "resourceType": "OperationOutcome",
        "id": "<identifier>",
        "meta": {
          "profile": [
            "https://fhir.nhs.uk/StructureDefinition/NHSDigital-OperationOutcome"
          ]
        },
        "issue": [
          {
            "code": "$issue_type",
            "severity": "$issue_level",
            "diagnostics": "$message",
            "details": {
              "coding": [
                {
                  "code": "$issue_code",
                  "display": "$issue_description",
                  "system": "https://fhir.nhs.uk/CodeSystem/Spine-ErrorOrWarningCode"
                }
              ]
            }
          }
        ]
      }
      """

  Scenario: Requesting producer does not have permission to create another producers document
    Given Producer "Aaron Court Mental Health NH" (Organisation ID "8FW23") is requesting to create Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") with pointer types
      | system                 | value           |
      | http://snomed.info/sct | 887701000000100 |
    When Producer "Aaron Court Mental Health NH" creates a Document Reference from DOCUMENT template
      | property    | value                             |
      | identifier  | 1234567892                        |
      | type        | 887701000000100                   |
      | custodian   | VLP01                             |
      | producer_id | VLP01                             |
      | subject     | 2742179658                        |
      | contentType | application/pdf                   |
      | url         | https://example.org/my-doc.pdf    |
      | system      | https://fhir.nhs.uk/Id/nhs-number |
    Then the operation is unsuccessful
    And the status is 400
    And the response is an OperationOutcome according to the OUTCOME template with the below values
      | property          | value                                                                                                |
      | issue_type        | processing                                                                                           |
      | issue_level       | error                                                                                                |
      | issue_code        | VALIDATION_ERROR                                                                                     |
      | issue_description | A parameter or value has resulted in a validation error                                              |
      | message           | The id of the provided document pointer does not include the expected organisation code for this app |

  Scenario Outline: Missing/invalid required params
    Given Producer "Aaron Court Mental Health NH" (Organisation ID "8FW23") is requesting to create Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") with pointer types
      | system                 | value     |
      | http://snomed.info/sct | 736253002 |
    When Producer "Aaron Court Mental Health NH" creates a Document Reference from DOCUMENT template
      | property    | value                             |
      | identifier  | <identifier>                      |
      | type        | <type>                            |
      | custodian   | 8FW23                             |
      | producer_id | 8FW23                             |
      | subject     | <subject>                         |
      | contentType | application/pdf                   |
      | url         | <url>                             |
      | system      | https://fhir.nhs.uk/Id/nhs-number |
    Then the operation is unsuccessful
    And the status is 400
    And the response is an OperationOutcome according to the OUTCOME template with the below values
      | property          | value                                                   |
      | issue_type        | processing                                              |
      | issue_level       | error                                                   |
      | issue_code        | VALIDATION_ERROR                                        |
      | issue_description | A parameter or value has resulted in a validation error |
      | message           | <message>                                               |

    Examples:
      | identifier | type      | subject           | url                            | message                                                                                               |
      | 1234567890 | 736253002 | 45646             | https://example.org/my-doc.pdf | DocumentReference validation failure - Invalid nhs_number - Not a valid NHS Number: 45646             |
      | 1234567890 | 736253002 |                   | https://example.org/my-doc.pdf | Empty value '' at 'subject.identifier.value' is not valid FHIR                                        |
      | 1234567890 | 736253002 | Device/9278693472 | https://example.org/my-doc.pdf | DocumentReference validation failure - Invalid nhs_number - Not a valid NHS Number: Device/9278693472 |

  Scenario: Duplicate Document Pointer
    Given Producer "Aaron Court Mental Health NH" (Organisation ID "8FW23") is requesting to create Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") with pointer types
      | system                 | value     |
      | http://snomed.info/sct | 736253002 |
    And a Document Pointer exists in the system with the below values for DOCUMENT template
      | property    | value                             |
      | identifier  | 1234567890                        |
      | type        | 736253002                         |
      | custodian   | 8FW23                             |
      | producer_id | 8FW23                             |
      | subject     | 9278693472                        |
      | contentType | application/pdf                   |
      | url         | https://example.org/my-doc.pdf    |
      | system      | https://fhir.nhs.uk/Id/nhs-number |
    When Producer "Aaron Court Mental Health NH" creates a Document Reference from DOCUMENT template
      | property    | value                             |
      | identifier  | 1234567890                        |
      | type        | 736253002                         |
      | custodian   | 8FW23                             |
      | producer_id | 8FW23                             |
      | subject     | 9278693472                        |
      | contentType | application/pdf                   |
      | url         | https://example.org/my-doc.pdf    |
      | system      | https://fhir.nhs.uk/Id/nhs-number |
    Then the operation is unsuccessful
    And the status is 400
    And the response is an OperationOutcome according to the OUTCOME template with the below values
      | property          | value                                   |
      | issue_type        | processing                              |
      | issue_level       | error                                   |
      | issue_code        | INVALID_RESOURCE_ID                     |
      | issue_description | Invalid resource ID                     |
      | message           | Condition check failed - Duplicate item |

  Scenario: Unable to create a Document Pointer when required field custodian is missing
    Given Producer "Aaron Court Mental Health NH" (Organisation ID "8FW23") is requesting to create Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") with pointer types
      | system                 | value     |
      | http://snomed.info/sct | 736253002 |
    When Producer "Aaron Court Mental Health NH" creates a Document Reference from BAD_DOCUMENT template
      | property    | value                          |
      | identifier  | 1234567890                     |
      | type        | 736253002                      |
      | producer_id | 8FW23                          |
      | subject     | 9278693472                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    Then the operation is unsuccessful
    And the status is 400
    And the response is an OperationOutcome according to the OUTCOME template with the below values
      | property          | value                                                   |
      | issue_type        | processing                                              |
      | issue_level       | error                                                   |
      | issue_code        | VALIDATION_ERROR                                        |
      | issue_description | A parameter or value has resulted in a validation error |
      | message           | The required field custodian is missing                 |

  Scenario: Unable to create a Document Pointer with an invalid id format
    Given Producer "Aaron Court Mental Health NH" (Organisation ID "8FW23") is requesting to create Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") with pointer types
      | system                 | value     |
      | http://snomed.info/sct | 736253002 |
    When Producer "Aaron Court Mental Health NH" creates a Document Reference from DOCUMENT_WITH_INVALID_ID_FORMAT template
      | property    | value                             |
      | identifier  | 1234567890                        |
      | type        | 736253002                         |
      | custodian   | 8FW23                             |
      | producer_id | 8FW23                             |
      | subject     | 9278693472                        |
      | contentType | application/pdf                   |
      | url         | https://example.org/my-doc.pdf    |
      | system      | https://fhir.nhs.uk/Id/nhs-number |
    Then the operation is unsuccessful
    And the status is 400
    And the response is an OperationOutcome according to the OUTCOME template with the below values
      | property          | value                                                     |
      | issue_type        | processing                                                |
      | issue_level       | error                                                     |
      | issue_code        | VALIDATION_ERROR                                          |
      | issue_description | A parameter or value has resulted in a validation error   |
      | message           | Input is not composite of the form a-b: 8FW23\|1234567890 |

  Scenario: Unable to create a Document Pointer when custodian does not match
    Given Producer "Aaron Court Mental Health NH" (Organisation ID "8FW23") is requesting to create Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") with pointer types
      | system                 | value     |
      | http://snomed.info/sct | 736253002 |
    When Producer "Aaron Court Mental Health NH" creates a Document Reference from DOCUMENT template
      | property    | value                             |
      | identifier  | 1234567890                        |
      | type        | 736253002                         |
      | custodian   | WRONG                             |
      | producer_id | 8FW23                             |
      | subject     | 9278693472                        |
      | contentType | application/pdf                   |
      | url         | https://example.org/my-doc.pdf    |
      | system      | https://fhir.nhs.uk/Id/nhs-number |
    Then the operation is unsuccessful
    And the status is 400
    And the response is an OperationOutcome according to the OUTCOME template with the below values
      | property          | value                                                                                                     |
      | issue_type        | processing                                                                                                |
      | issue_level       | error                                                                                                     |
      | issue_code        | VALIDATION_ERROR                                                                                          |
      | issue_description | A parameter or value has resulted in a validation error                                                   |
      | message           | The custodian of the provided document pointer does not match the expected organisation code for this app |

  Scenario: Unable to create a Document Pointer when body is invalid json
    Given Producer "Aaron Court Mental Health NH" (Organisation ID "8FW23") is requesting to create Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") with pointer types
      | system                 | value     |
      | http://snomed.info/sct | 736253002 |
    When Producer "Aaron Court Mental Health NH" creates a Document Reference with bad json
      """
      {I am bad}
      """
    Then the operation is unsuccessful
    And the status is 400
    And the response is an OperationOutcome according to the OUTCOME template with the below values
      | property          | value                                                   |
      | issue_type        | processing                                              |
      | issue_level       | error                                                   |
      | issue_code        | VALIDATION_ERROR                                        |
      | issue_description | A parameter or value has resulted in a validation error |
      | message           | Body is not valid json                                  |

  Scenario: Unable to create a Document Pointer with an invalid custodian system value
    Given Producer "Aaron Court Mental Health NH" (Organisation ID "8FW23") is requesting to create Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") with pointer types
      | system                 | value     |
      | http://snomed.info/sct | 736253002 |
    When Producer "Aaron Court Mental Health NH" creates a Document Reference from DOCUMENT_WITH_INVALID_CUSTODIAN_SYSTEM template
      | property    | value                             |
      | identifier  | 1234567890                        |
      | type        | 736253002                         |
      | custodian   | 8FW23                             |
      | producer_id | 8FW23                             |
      | subject     | 9278693472                        |
      | contentType | application/pdf                   |
      | url         | https://example.org/my-doc.pdf    |
      | system      | https://fhir.nhs.uk/Id/nhs-number |
    Then the operation is unsuccessful
    And the status is 400
    And the response is an OperationOutcome according to the OUTCOME template with the below values
      | property          | value                                                      |
      | issue_type        | processing                                                 |
      | issue_level       | error                                                      |
      | issue_code        | VALIDATION_ERROR                                           |
      | issue_description | A parameter or value has resulted in a validation error    |
      | message           | Provided custodian identifier system is not the ODS system |

  Scenario: Unable to create a Document Pointer when the producer is not the custodian
    Given Producer "BaRS (EMIS)" (Organisation ID "V4T0L.YGMMC") is requesting to create Document Pointers
    And Producer "BaRS (EMIS)" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") with pointer types
      | system                 | value     |
      | http://snomed.info/sct | 736253002 |
    When Producer "BaRS (EMIS)" creates a Document Reference from DOCUMENT template
      | property    | value                             |
      | identifier  | 1234567890                        |
      | type        | 736253002                         |
      | custodian   | V4T0L                             |
      | producer_id | V4T0L.YGMMC                       |
      | subject     | 9278693472                        |
      | contentType | application/pdf                   |
      | url         | https://example.org/my-doc.pdf    |
      | system      | https://fhir.nhs.uk/Id/nhs-number |
    Then the operation is unsuccessful
    And the status is 400
    And the response is an OperationOutcome according to the OUTCOME template with the below values
      | property          | value                                                                                                     |
      | issue_type        | processing                                                                                                |
      | issue_level       | error                                                                                                     |
      | issue_code        | VALIDATION_ERROR                                                                                          |
      | issue_description | A parameter or value has resulted in a validation error                                                   |
      | message           | The custodian of the provided document pointer does not match the expected organisation code for this app |

  Scenario: Unable to create a Document Pointer with an invalid subject.identifier.system value
    Given Producer "Aaron Court Mental Health NH" (Organisation ID "8FW23") is requesting to create Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") with pointer types
      | system                 | value     |
      | http://snomed.info/sct | 736253002 |
    When Producer "Aaron Court Mental Health NH" creates a Document Reference from DOCUMENT template
      | property    | value                          |
      | identifier  | 1234567890-1                   |
      | type        | 736253002                      |
      | custodian   | 8FW23                          |
      | producer_id | 8FW23                          |
      | subject     | 9278693472                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
      | system      | Test                           |
    Then the operation is unsuccessful
    And the status is 400
    And the response is an OperationOutcome according to the OUTCOME template with the below values
      | property          | value                                                   |
      | issue_type        | processing                                              |
      | issue_level       | error                                                   |
      | issue_code        | VALIDATION_ERROR                                        |
      | issue_description | A parameter or value has resulted in a validation error |
      | message           | Input FHIR JSON has an invalid subject:identifier       |

  Scenario: Unable to create a Document Pointer when json body has multiple keys
    Given Producer "Aaron Court Mental Health NH" (Organisation ID "8FW23") is requesting to create Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") with pointer types
      | system                 | value     |
      | http://snomed.info/sct | 736253002 |
    When Producer "Aaron Court Mental Health NH" creates a Document Reference with bad json
      """
      {
        "subject": {
          "identifier": {
            "system": "https://fhir.nhs.uk/Id/nhs-number",
            "value": "subjectone"
          }
        },
        "subject": {
          "identifier": {
            "system": "https://fhir.nhs.uk/Id/nhs-number",
            "value": "subjecttwo"
          }
        }
      }
      """
    Then the operation is unsuccessful
    And the status is 400
    And the response is an OperationOutcome according to the OUTCOME template with the below values
      | property          | value                                                   |
      | issue_type        | processing                                              |
      | issue_level       | error                                                   |
      | issue_code        | VALIDATION_ERROR                                        |
      | issue_description | A parameter or value has resulted in a validation error |
      | message           | Duplicate key: 'subject'                                |
