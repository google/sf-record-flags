/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @description Unit tests for RecordFlags.
 */
@IsTest(isParallel=true)
private class RecordFlagsTest {
  private static Boolean hasPermissionToFlag = true;
  private static List<Record_Flag__mdt> flags = new List<Record_Flag__mdt>();
  private static Map<String, Object> interviewResults = new Map<String, Object>();
  private static SObject sharedData = null;

  static {
    RecordFlags.selector = new RecordFlagsTest.MockSelector();
    RecordFlags.interview = new RecordFlagsTest.MockInterview();
  }

  @IsTest
  private static void getFetchers_shouldReturnShellObjectWhenNoSharedDataPresent() {
    Id recordId = mockId(Account.SObjectType);
    flags = new List<Record_Flag__mdt>();

    RecordFlags.Fetchers result = RecordFlags.getFetchers(
      recordId,
      Account.SObjectType.toString()
    );

    Assert.isTrue(
      result.fetchers.isEmpty(),
      'Expected no flag fetchers to be returned'
    );
    Assert.areEqual(
      result.sharedData,
      new Account(Id = recordId),
      'Expected shelled SObject to be returned'
    );
  }

  @IsTest
  private static void getFetchers_shouldInvokeSharedDataWhenProvided() {
    Id recordId = mockId(Account.SObjectType);
    sharedData = new Account(Id = recordId, Name = 'Test Account');
    flags = new List<Record_Flag__mdt>{
      new Record_Flag__mdt(
        Apex_Class_Name__c = 'RecordFlagsTest.MockSharedData',
        Is_Data_Fetcher__c = true,
        Object__c = 'Account'
      )
    };

    RecordFlags.Fetchers result = RecordFlags.getFetchers(
      recordId,
      Account.SObjectType.toString()
    );

    Assert.isTrue(
      result.fetchers.isEmpty(),
      'Expected no flag fetchers to be returned'
    );
    Assert.areEqual(
      sharedData,
      result.sharedData,
      'Expected shared data to be returned'
    );
  }

  @IsTest
  private static void getFetchers_shouldNotReturnFetcherWhenNoPermission() {
    Id recordId = mockId(Account.SObjectType);
    hasPermissionToFlag = false;
    flags = new List<Record_Flag__mdt>{
      new Record_Flag__mdt(
        Apex_Class_Name__c = 'RecordFlagsTest.AccountNameEchoFlag',
        Custom_Permission__c = 'Some_Permission_User_Doesnt_Have',
        Object__c = 'Account'
      )
    };

    RecordFlags.Fetchers result = RecordFlags.getFetchers(recordId, 'Account');

    Assert.isTrue(
      result.fetchers.isEmpty(),
      'Expected no flag fetchers to be returned'
    );
  }

  @IsTest
  private static void invokeFetchers_shouldCorrectlyPassDataAndBuildFlagApex() {
    Id recordId = mockId(Account.SObjectType);
    Account account = new Account(Id = recordId, Name = 'Test Account');
    sharedData = account;

    flags = new List<Record_Flag__mdt>{
      new Record_Flag__mdt(
        Apex_Class_Name__c = 'RecordFlagsTest.MockSharedData',
        Is_Data_Fetcher__c = true,
        Object__c = 'Account'
      ),
      new Record_Flag__mdt(
        Apex_Class_Name__c = 'RecordFlagsTest.AccountNameEchoFlag',
        Object__c = 'Account'
      )
    };

    RecordFlags.Fetchers fetchers = RecordFlags.getFetchers(
      recordId,
      'Account'
    );

    Assert.areEqual(
      1,
      fetchers.fetchers.size(),
      'Expected single fetcher to be returned'
    );

    RecordFlag[] result = RecordFlags.invokeFetcher(
      fetchers.sharedData,
      fetchers.fetchers[0]
    );

    Assert.areEqual(1, result.size(), 'Expected one flag to be returned');
    Assert.areEqual(
      account.Name,
      result[0].title,
      'Flag title should match account name'
    );
    Assert.areEqual(
      3,
      result[0].buttons.size(),
      'All buttons should be returned by Fetcher'
    );
  }

  @IsTest
  private static void invokeFetchers_shouldCorrectlyPassDataAndBuildFlagFlow() {
    Id recordId = mockId(Account.SObjectType);
    interviewResults.put(
      'recordFlag',
      new RecordFlag(RecordFlag.Variant.NORMAL, 'Flow Flag #1', null)
    );
    interviewResults.put(
      'recordFlags',
      new List<RecordFlag>{
        new RecordFlag(RecordFlag.Variant.NORMAL, 'Flow Flag #2')
      }
    );

    RecordFlag[] result = RecordFlags.invokeFetcher(
      new Account(),
      new Record_Flag__mdt(Flow_Name__c = 'FakeFlow', Object__c = 'Account')
    );

    Assert.areEqual(2, result.size(), 'Expected two flag to be returned');
    Assert.areEqual(
      'Flow Flag #1',
      result[0].title,
      'Flag title should match flow data'
    );
    Assert.areEqual(
      'Flow Flag #2',
      result[1].title,
      'Flag title should match flow data'
    );
  }

  @IsTest
  private static void invokeFetchers_shouldReturnErrorFlagWhenApexFlagThrowsException() {
    // Account with no name will throw an exception
    Id recordId = mockId(Account.SObjectType);
    sharedData = new Account(Id = recordId);

    flags = new List<Record_Flag__mdt>{
      new Record_Flag__mdt(
        Apex_Class_Name__c = 'RecordFlagsTest.AccountNameEchoFlag',
        Object__c = 'Account'
      )
    };

    RecordFlags.Fetchers fetchers = RecordFlags.getFetchers(
      recordId,
      'Account'
    );
    RecordFlag[] result = RecordFlags.invokeFetcher(
      fetchers.sharedData,
      fetchers.fetchers[0]
    );

    Assert.areEqual(1, result.size());
    Assert.areEqual(RecordFlag.Variant.ERROR.toString(), result[0].variant);
    Assert.isTrue(
      result[0].body.contains('Bad Account Data!'),
      'Error message should be included in the body'
    );
    Assert.isTrue(
      result[0].body.contains('AccountNameEchoFlag'),
      'Problematic Apex class should be included in the body'
    );
  }

  @IsTest
  private static void invokeFetchers_shouldReturnErrorFlagWhenFlowFlagThrowsException() {
    // Null results will throw an exception
    interviewResults = null;

    RecordFlag[] result = RecordFlags.invokeFetcher(
      new Account(),
      new Record_Flag__mdt(Flow_Name__c = 'FakeFlow', Object__c = 'Account')
    );

    Assert.areEqual(1, result.size());
    Assert.areEqual(RecordFlag.Variant.ERROR.toString(), result[0].variant);
    Assert.isTrue(
      result[0].body.contains('Flow encountered an issue'),
      'Error message should be included in the body'
    );
    Assert.isTrue(
      result[0].body.contains('FakeFlow'),
      'Problematic Flow should be included in the body'
    );
  }

  @IsTest
  private static void getFetchers_standardSelectorShouldSucceedInQuery() {
    Exception ex = null;

    try {
      new RecordFlags.Selector().getFetchers('Account');
    } catch (Exception e) {
      ex = e;
    }

    Assert.isNull(ex, 'Expected query to succeed without exception');
  }

  private static Id mockId(Schema.SObjectType sObjectType) {
    return sObjectType.getDescribe().getKeyPrefix() + '000000000001';
  }

  /**
   * A mock implementation of any interactions with the Salesforce database.
   */
  private class MockSelector extends RecordFlags.Selector {
    public override List<Record_Flag__mdt> getFetchers(String objectName) {
      return flags;
    }

    public override Boolean hasPermission(String customPermission) {
      return hasPermissionToFlag;
    }
  }

  /**
   * A mock implementation of any Flow Interview invoked by the system.
   */
  private inherited sharing virtual class MockInterview extends RecordFlags.Interview {
    public override void createInterview(
      String flowApiName,
      Map<String, Object> inputs
    ) {
      // Do nothing, no real Interview will be invoked.
    }

    public override void start() {
      // Do nothing, no real Interview will be invoked.
    }

    public override Object getOptionalVariable(String variableName) {
      if (interviewResults == null) {
        throw new IllegalArgumentException('Flow encountered an issue!');
      }
      return interviewResults.get(variableName);
    }
  }

  public class MockSharedData extends RecordFlags.SharedData {
    public override SObject getRecord(Id recordId) {
      return sharedData;
    }
  }

  public class AccountNameEchoFlag extends RecordFlags.Fetcher {
    public override RecordFlag[] getFlags(SObject record) {
      Account a = (Account) record;
      if (String.isEmpty(a.Name)) {
        throw new IllegalArgumentException('Bad Account Data!');
      }
      return listOf(
        new RecordFlag(
          RecordFlag.Variant.NORMAL,
          a.Name,
          null,
          new List<RecordFlagButton>{
            new RecordFlagButton(),
            new RecordFlagButton('Constructive', 'Coverage'),
            new RecordFlagButton('Is', 'Very', 'Important')
          }
        )
      );
    }
  }
}
