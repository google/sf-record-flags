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
 */

import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { registerRefreshHandler, unregisterRefreshHandler } from "lightning/refresh";
import getActiveFlagsMdt from "@salesforce/apex/RecordFlags.getFetchers";

export default class RecordFlags extends LightningElement {
  @api recordId;
  @api objectApiName;

  haveFlags = false;
  haveErrors = false;
  listOfActiveMdt = [];
  existingFlag = [];
  record;
  refreshHandlerID;
  
  connectedCallback() {
    this.getData();
    if (!this.refreshHandlerID) {
      this.refreshHandlerID = registerRefreshHandler(this, this.handleRefresh);
    }
  }

  disconnectedCallback() {
    if (this.refreshHandlerID) {
      unregisterRefreshHandler(this.refreshHandlerID);
    }
  }

  getData() {
    getActiveFlagsMdt({
      recordId: this.recordId,
      objectName: this.objectApiName
    })
      .then((result) => {
        console.log(result);
        
        this.listOfActiveMdt = result.fetchers;
        this.record = result.sharedData;
        this.haveFlags = true;
      })
      .catch((error) => {
        this.handleError(error);
      });
  }

  handleRefresh() {
    return new Promise((resolve) => {
      this.getData();
      resolve(true);
    });
  }

  /**
   * Method handles response from the child lwc
   * @param data - response from the child lwc
   */
  @api handleChildRecordFlags(event) {
    let flagData = event.detail;
    if (flagData.length > 0) {
      flagData.forEach((childFlag) => {
        if (JSON.stringify(this.existingFlag).includes("Component Error")) {
          if (this.existingFlag[0].body !== childFlag.body) {
            //accommodate all child errors in 1 flag
            this.existingFlag[0].body =
              this.existingFlag[0].body + "\n" + childFlag.body;
          }
        } else {
          //first error flag
          this.existingFlag.push(childFlag);
        }
      });
      this.haveErrors = true;
    }
  }

  /**
   * Method to handle error
   * @param error - error object
   */
  handleError(error) {
    let errorMessage = "Something went wrong in recordFlags! ";
    if (error?.body?.output?.errors?.[0]) {
      errorMessage = errorMessage + error.body.output.errors[0].message;
    } else if (error?.body?.message) {
      errorMessage = errorMessage + error.body.message;
    }
    this.showToast("Error", errorMessage, "error");
  }
  
  /**
   * Method to show component errors
   * @param theTitle - the title of the error
   * @param theMessage - the message of the error
   * @param theVariant - the variant of the error
   */
  showToast(theTitle, theMessage, theVariant) {
    const event = new ShowToastEvent({
      title: theTitle,
      message: theMessage,
      variant: theVariant
    });
    this.dispatchEvent(event);
  }
}
