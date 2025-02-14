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

import { LightningElement, api, track } from "lwc";
import getFlags from "@salesforce/apex/RecordFlags.invokeFetcher";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const varientCSS = {
  NORMAL: "slds-badge slds-badge_inverse",
  SUCCESS: "slds-badge slds-theme_success",
  WARNING: "slds-badge slds-theme_warning",
  ERROR: "slds-badge slds-theme_error"
};

export default class RecordFlagFetcher extends LightningElement {
  @api errorRecordFlag;
  @track listOfRecordFlags = [];
  loading = true;
  @api recordId;
  @api objectApiName;
  @api mdtRecord;
  @api record;
  @api wrapper;
  list = [];

  /**
   * Method is fired when LWC is inserted into the DOM
   */
  connectedCallback() {
    if (this.record && this.mdtRecord) {
      this.getData();
    } else {
      if (this.errorRecordFlag) {
        this.listOfRecordFlags.push(
          JSON.parse(JSON.stringify(this.errorRecordFlag))
        );
      }
      this.loading = false;
    }
  }

  getData() {
    getFlags({
      sharedData: this.record,
      fetcherConfig: this.mdtRecord
    })
      .then((result) => {
        this.handleRecordFlags(result);
      })
      .catch((error) => {
        this.loading = false;
        this.handleError(error);
      });
  }

  /**
   * Method handles response from the apex class
   * @param data - response from the apex
   */
  handleRecordFlags(data) {
    let flagData = data;

    if (flagData.length > 0) {
      flagData.forEach((value, index) => {
        let flag = {
          ...value,
          key: "key_" + index,
          showDetails: false,
          varientCSS: varientCSS[value.variant],
          hasButtons: value.buttons ? true : false,
          isClicked: false
        };

        if (flag.hasButtons) {
          flag.buttons.forEach((button, index2) => {
            button.key = "button_" + index2;
          });
        }
        if (JSON.stringify(value).includes("Component Error")) {
          // send it to parent
          this.list.push(flag);
          const selectedEvent = new CustomEvent("errorreceive", {
            detail: this.list
          });
          // Dispatches the event.
          this.dispatchEvent(selectedEvent);
        } else {
          this.listOfRecordFlags.push(flag);
        }
      });
    }
    this.loading = false;
  }

  get haveFlags() {
    return this.listOfRecordFlags.length > 0;
  }
  
  /**
   * Method to handle badge click
   * @param event - event object for badge click action
   */
  handleBadgeClick(event) {
    let elementKey = event.currentTarget.getAttribute("data-div-id");
    this.listOfRecordFlags.forEach((flag, index) => {
      if (flag.key === elementKey) {
        flag.showDetails = !flag.body && !flag.hasButtons ? false : true;
        flag.isClicked = true;
      }
      this.listOfRecordFlags[index] = flag;
    });
  }

  /**
   * Method to handle mouse actions on the badges
   * @param event - event object for mouse over action
   */
  handleMouseOver(event) {
    let elementKey = event.currentTarget.getAttribute("data-div-id");
    this.listOfRecordFlags.forEach((flag, index) => {
      if (!flag.isClicked && flag.key === elementKey) {
        flag.showDetails =
          !flag.body && !flag.hasButtons ? false : !flag.showDetails;
      }
      this.listOfRecordFlags[index] = flag;
    });
  }

  /**
   * Method to handle mouse actions on the badges
   * @param event - event object for mouse out action
   */
  handleMouseOut(event) {
    let elementKey = event.currentTarget.getAttribute("data-div-id");
    this.listOfRecordFlags.forEach((flag, index) => {
      if (!flag.isClicked && flag.key === elementKey) {
        flag.showDetails =
          !flag.body && !flag.hasButtons ? false : !flag.showDetails;
      }
      this.listOfRecordFlags[index] = flag;
    });
  }

  /**
   * Method to handle popover close
   * @param event - event object on close action
   */
  handlePopOverCancel(event) {
    let elementKey = event.currentTarget.getAttribute("data-div-id");
    this.listOfRecordFlags.forEach((flag, index) => {
      if (flag.key === elementKey) {
        flag.showDetails = false;
        flag.isClicked = false;
      }
      this.listOfRecordFlags[index] = flag;
    });
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
