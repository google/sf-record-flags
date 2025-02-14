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
 * @description A RecordFlagButton represents a call to action when a user
 * hovers over a RecordFlag. The button should have a label and a URL to take
 * the user to when clicked on.
 */
public class RecordFlagButton {
  /**
   * The label of the button when it is rendered on the screen.
   */
  @AuraEnabled
  public String name;

  /**
   * The manner in which the link should be opened when clicked:
   *    _blank  - Opens the linked document in a new window or tab.
   *    _self   - Opens the linked document in the same frame as it was clicked.
   *    _parent - Opens the linked document in the parent frame.
   *    _top	  - Opens the linked document in the full body of the window.
   */
  @AuraEnabled
  public String target;

  /**
   * The URL the user should be brought to when the button is clicked. URLs can
   * be either relative or absolute.
   */
  @AuraEnabled
  public String url;

  /** A parameterless constructor necessary for using in Flows. */
  public RecordFlagButton() {
  }

  /**
   * Constructs a new `RecordFlagButton` instance.
   *
   * @param name - The label of the button when it is rendered on the screen.
   * @param url - The URL to navigate to to when the button is clicked.
   */
  public RecordFlagButton(String name, String url) {
    this.name = name;
    this.url = url;
    this.target = '_blank';
  }

  /**
   * Constructs a new `RecordFlagButton` instance.
   *
   * @param name - The label of the button when it is rendered on the screen.
   * @param url - The URL to navigate to to when the button is clicked.
   * @param target - The way the link should be opened when clicked.
   */
  public RecordFlagButton(String name, String url, String target) {
    this.name = name;
    this.url = url;
    this.target = target;
  }
}
