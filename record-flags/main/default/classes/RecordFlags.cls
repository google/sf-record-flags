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
 * @description The primary logic class for fetching RecordFlag configurations
 * and determining the actual flags that should be rendered onto a record page.
 * This class is designed to be called by the recordFlags LWC.
 */
public with sharing class RecordFlags {
  @TestVisible
  private static final String ERROR_TITLE = 'Record Flags Error';
  @TestVisible
  private static RecordFlags.Selector selector = new RecordFlags.Selector();
  @TestVisible
  private static RecordFlags.Interview interview = new RecordFlags.Interview();

  /**
   * A class that extends RecordFlags.Fetcher is eligible to be invoked by
   * the RecordFlags LWC to render the series of flags returned by the class.
   */
  public abstract class Fetcher {
    /**
     * @description Logic to calculate what flags to render for the record.
     * @param sharedData - A record of shared data across fetchers fetched by a
     * RecordFlags.SharedData class. If no such class was defined, this record
     * will still be present with only the Id field provided.
     * @return RecordFlag[] - The flags to render, or null to render nothing.
     */
    public abstract RecordFlag[] getFlags(SObject sharedData);

    /**
     * @description Utility method to return a single RecordFlag in getFlags.
     * @param flag - The single RecordFlag to convert to a list.
     * @return RecordFlag[] - A list containing the single flag.
     */
    public RecordFlag[] listOf(RecordFlag flag) {
      return new List<RecordFlag>{ flag };
    }
  }

  /**
   * Although each RecordFlags.Fetcher class is run in its own separate Apex
   * transaction, it can be beneficial to share around common fields between
   * classes to avoid separate SOQL queries and speed up overall performance.
   * Each Object is allowed to define a single RecordFlags.SharedData class
   * to query and return the relevant fields associated with the record that
   * matches the record ID. This data is passed into the getFlags(record)
   * method invoked by each RecordFlags.Fetcher class.
   *
   * Note that it's completely optional to defined a SharedData class. Each
   * individual Fetcher class can handle its own SOQL queries. Complex
   * queries may benefit from being handled within the individual Fetcher.
   *
   * If multiple SharedData classes are defined for an object, only one will
   * be arbitrarily chosen, so it is dangerous to violate this rule.
   */
  public abstract class SharedData {
    /**
     * Fetches relevant data related to the record to pass to all
     * RecordFlags.Fetcher instances for this SObject.
     *
     * @param recordId - Id of the record.
     * @return SObject - The queried data for the Object.
     */
    public abstract SObject getRecord(Id recordId);
  }

  /**
   * Represents a collection of fetcher data to be passed to the Lightning Web
   * Component (LWC). The data is split across LWC calls to ensure each fetcher
   * runs in its own Apex transaction, preventing limit errors.
   */
  public class Fetchers {
    /**
     * The shared data passed to each `RecordFlags.Fetcher.getFlags(record)`
     * call. This data is fetched by a designated `RecordFlags.SharedData`
     * class and provides a common set of record information to all fetchers,
     * optimizing performance by avoiding redundant queries. If no `SharedData`
     * class is defined, this will contain a new SObject instance with only
     * the record Id populated.
     */
    @AuraEnabled
    public SObject sharedData;

    /**
     * The list of record flag fetchers (`Record_Flag__mdt` records) to be
     * invoked for this record page. These records define the configuration
     * for each fetcher, such as the Apex class or Flow to execute, and are
     * ordered by the `Order__c` field.
     */
    @AuraEnabled
    public Record_Flag__mdt[] fetchers;

    /**
     * Constructs a new `Fetchers` instance.
     *
     * @param sharedData The shared data to be used by all fetchers.
     * @param fetchers The ordered list of `Record_Flag__mdt` records defining
     * the fetchers to invoke.
     */
    public Fetchers(SObject sharedData, Record_Flag__mdt[] fetchers) {
      this.sharedData = sharedData;
      this.fetchers = fetchers;
    }
  }

  /**
   * Retrieves the record flag fetchers for the specified record and object.
   *
   * @param recordId The ID of the record.
   * @param objectName The API name of the object.
   * @return A `Fetchers` instance containing the shared data and the list of
   * fetchers.
   */
  @AuraEnabled
  public static RecordFlags.Fetchers getFetchers(
    Id recordId,
    String objectName
  ) {
    Record_Flag__mdt sharedDataFetcher = null;
    List<Record_Flag__mdt> fetchers = new List<Record_Flag__mdt>();

    Record_Flag__mdt[] unsortedFetchers = selector.getFetchers(objectName);
    for (Record_Flag__mdt fetcher : unsortedFetchers) {
      if (hasPermission(fetcher.Custom_Permission__c)) {
        if (fetcher.Is_Data_Fetcher__c) {
          sharedDataFetcher = fetcher;
        } else {
          fetchers.add(fetcher);
        }
      }
    }

    try {
      SObject sharedData = null;
      if (sharedDataFetcher != null) {
        sharedData = invokeDataFetcher(sharedDataFetcher, recordId);
      } else {
        Schema.SObjectType objectType = Schema.getGlobalDescribe()
          .get(objectName);
        sharedData = objectType.newSObject(recordId);
      }
      return new RecordFlags.Fetchers(sharedData, fetchers);
    } catch (Exception ex) {
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /**
   * Invokes the specified fetcher and returns the resulting flags.
   *
   * @param sharedData The shared data to be passed to the fetcher.
   * @param fetcherConfig The `Record_Flag__mdt` record defining the fetcher.
   * @return An array of `RecordFlag` objects representing the flags to render.
   */
  @AuraEnabled
  public static RecordFlag[] invokeFetcher(
    SObject sharedData,
    Record_Flag__mdt fetcherConfig
  ) {
    List<RecordFlag> flags = new List<RecordFlag>();
    System.debug(sharedData);
    System.debug(fetcherConfig);

    try {
      RecordFlag[] results = invokeFlagFetcher(fetcherConfig, sharedData);
      if (results != null) {
        flags.addAll(results);
      }
    } catch (Exception ex) {
      String errorMsg;
      if (fetcherConfig.Apex_Class_Name__c != null) {
        errorMsg =
          'Error occured while loading flag from ' +
          fetcherConfig.Apex_Class_Name__c +
          ' : ' +
          ex.getMessage();
      } else if (fetcherConfig.Flow_Name__c != null) {
        errorMsg =
          'Error occured while loading flag from ' +
          fetcherConfig.Flow_Name__c +
          ' : ' +
          ex.getMessage();
      } else {
        errorMsg =
          'Error occured while loading invokeFetcher() : ' + ex.getMessage();
      }
      flags.add(
        new RecordFlag(RecordFlag.Variant.ERROR, ERROR_TITLE, errorMsg)
      );
    }
    return flags;
  }

  /**
   * Checks if the running user has the specified custom permission.
   *
   * @param customPermission The API name of the custom permission.
   * @return `true` if the user has the permission, `false` otherwise.
   */
  private static Boolean hasPermission(String customPermission) {
    return String.isBlank(customPermission)
      ? true
      : selector.hasPermission(customPermission);
  }

  /**
   * Invokes the shared data fetcher and returns the shared data.
   *
   * @param fetcherConfig The `Record_Flag__mdt` record defining the fetcher.
   * @param recordId The ID of the record.
   * @return The shared data as an `SObject`.
   */
  private static SObject invokeDataFetcher(
    Record_Flag__mdt fetcherConfig,
    Id recordId
  ) {
    RecordFlags.SharedData fetcher = (RecordFlags.SharedData) Type.forName(
        fetcherConfig.Apex_Class_Name__c
      )
      .newInstance();
    return fetcher.getRecord(recordId);
  }

  /**
   * Invokes the appropriate flag fetcher (Apex or Flow) based on the provided
   * configuration.
   *
   * @param fetcherConfig The `Record_Flag__mdt` record defining the fetcher.
   * @param sharedData The shared data to be passed to the fetcher.
   * @return An array of `RecordFlag` objects fetched by the fetcher.
   */
  private static RecordFlag[] invokeFlagFetcher(
    Record_Flag__mdt fetcherConfig,
    SObject sharedData
  ) {
    if (String.isNotBlank(fetcherConfig.Apex_Class_Name__c)) {
      return invokeApexFlagFetcher(fetcherConfig, sharedData);
    }
    if (String.isNotBlank(fetcherConfig.Flow_Name__c)) {
      return invokeFlowFlagFetcher(fetcherConfig, sharedData);
    }
    return null;
  }

  /**
   * Invokes an Apex flag fetcher.
   *
   * @param fetcherConfig The `Record_Flag__mdt` record defining the Apex
   * fetcher configuration.
   * @param sharedData The shared data to be passed to the fetcher.
   * @return An array of `RecordFlag` objects.
   */
  private static RecordFlag[] invokeApexFlagFetcher(
    Record_Flag__mdt fetcherConfig,
    SObject sharedData
  ) {
    RecordFlags.Fetcher fetcher = (RecordFlags.Fetcher) Type.forName(
        fetcherConfig.Apex_Class_Name__c
      )
      .newInstance();
    return fetcher.getFlags(sharedData);
  }

  /**
   * Invokes a Flow flag fetcher.
   *
   * @param fetcherConfig The `Record_Flag__mdt` record defining the Flow
   * fetcher configuration.
   * @param sharedData The shared data to be passed to the fetcher.
   * @return An array of `RecordFlag` objects.
   */
  private static RecordFlag[] invokeFlowFlagFetcher(
    Record_Flag__mdt fetcherConfig,
    SObject sharedData
  ) {
    List<RecordFlag> result = new List<RecordFlag>();
    Map<String, Object> inputs = new Map<String, Object>{
      'recordId' => sharedData.Id
    };

    try {
      interview.createInterview(fetcherConfig.Flow_Name__c, inputs);
      interview.start();
    } catch (System.TypeException e) {
      throw new IllegalArgumentException('Flow does not exist');
    }

    RecordFlag flag = (RecordFlag) interview.getOptionalVariable('recordFlag');
    if (flag != null) {
      result.add(flag);
    }
    RecordFlag[] flags = (RecordFlag[]) interview.getOptionalVariable(
      'recordFlags'
    );
    if (flags != null) {
      result.addAll(flags);
    }

    return result;
  }

  /**
   * Private inner class that handles data fetching logic. Allows for queries
   * to be easily mocked in unit tests without relying on instance-specific
   * validation rules or trigger pertaining to specific SObjects.
   */
  @TestVisible
  private inherited sharing virtual class Selector {
    /**
     * Fetch active Record_Flag__mdt records for the SObject type.
     *
     * @param objectName - The name of the SObject.
     * @return List<Record_Flag__mdt> - The list of defined active flags.
     */
    public virtual List<Record_Flag__mdt> getFetchers(String objectName) {
      return [
        SELECT
          Apex_Class_Name__c,
          Custom_Permission__c,
          Flow_Name__c,
          Is_Data_Fetcher__c,
          Order__c
        FROM Record_Flag__mdt
        WHERE Object__c = :objectName AND Is_Active__c = TRUE
        ORDER BY Order__c ASC
      ];
    }

    /**
     * Checks if the running user has the custom permission.
     *
     * @param customPermission - API name of the custom permission.
     * @return Boolean indicating if the user has the permission.
     */
    public virtual Boolean hasPermission(String customPermission) {
      return FeatureManagement.checkPermission(customPermission);
    }
  }

  /**
   * Private inner class that handles Flow invocations. Allows for interactions
   * to be easily mocked in unit tests without relying on instance-specific
   * flows.
   */
  @TestVisible
  private inherited sharing virtual class Interview {
    @TestVisible
    private Flow.Interview instance;

    /**
     * Initializes an Interview.
     *
     * @param flowApiName - API name of the autolaunched flow to be dynamically
     * instantiated.
     * @param inputs - Map of inputs to the flow.
     */
    public virtual void createInterview(
      String flowApiName,
      Map<String, Object> inputs
    ) {
      this.instance = Flow.Interview.createInterview(flowApiName, inputs);
    }

    /**
     * Starts the interview initialized via `createInterview`.
     */
    public virtual void start() {
      this.instance.start();
    }

    /**
     * @description - Retrieves the value of an output variable from the flow.
     * @param variableName - API name of the variable within the flow.
     * @return - The output variable's value.
     */
    public virtual Object getOptionalVariable(String variableName) {
      try {
        return this.instance.getVariableValue(variableName);
      } catch (System.NullPointerException e) {
        return null;
      }
    }
  }

  /**
   * RecordFlags should only be invoked in a static context.
   */
  private RecordFlags() {
  }
}
