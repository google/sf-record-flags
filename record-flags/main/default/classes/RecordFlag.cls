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
 * @description A RecordFlag represents a singular badge that will be
 * rendered onto a record page. This flag should always have a title, and can
 * include an optional body String that provides the user additional context,
 * along with an optional list of buttons, which provide calls to action for
 * the user to take.
 *
 * The flag will be rendered as Lightning Design System Badge.
 * See https://www.lightningdesignsystem.com/components/badges/
 */
public class RecordFlag {
  /**
   * An optional list of actions a user can take with regards to this flag.
   */
  @AuraEnabled
  public RecordFlagButton[] buttons;

  /**
   * An optional text box that is displayed when the user hovers over the flag badge.
   */
  @AuraEnabled
  public String body;

  /**
   * The text that is displayed on the flag when rendered. Required.
   */
  @AuraEnabled
  public String title;

  /**
   * The color of the badge to be rendered. Required.
   * Valid choices are [NORMAL, SUCCESS, WARNING, ERROR].
   * See https://www.lightningdesignsystem.com/components/badges/#Colors.
   */
  @AuraEnabled
  public String variant;

  /** A parameterless constructor necessary for using in Flows. */
  public RecordFlag() {
  }

  /**
   * Constructs a new `RecordFlag` instance.
   *
   * @param variant - The color of the badge to be rendered.
   * @param title - The text that is displayed on the flag when rendered.
   */
  public RecordFlag(RecordFlag.Variant variant, String title) {
    this(variant, title, null);
  }

  /**
   * Constructs a new `RecordFlag` instance.
   *
   * @param variant - The color of the badge to be rendered.
   * @param title - The text that is displayed on the flag when rendered.
   * @param body - The text that is displayed when hovering over the flag.
   */
  public RecordFlag(RecordFlag.Variant variant, String title, String body) {
    this(variant, title, body, null);
  }

  /**
   * Constructs a new `RecordFlag` instance.
   *
   * @param variant - The color of the badge to be rendered.
   * @param title - The text that is displayed on the flag when rendered.
   * @param body - The text that is displayed when hovering over the flag.
   * @param buttons - A list of RecordFlagButtons to display when hovering.
   */
  public RecordFlag(
    RecordFlag.Variant variant,
    String title,
    String body,
    RecordFlagButton[] buttons
  ) {
    this.variant = variant.toString();
    this.title = title;
    this.body = body;
    this.buttons = buttons;
  }

  /**
   * The color of the badge to be rendered.
   * See https://www.lightningdesignsystem.com/components/badges/#Colors.
   */
  public enum Variant {
    NORMAL, //  slds-badge_inverse
    SUCCESS, // slds-theme_success
    WARNING, // slds-theme_warning
    ERROR //    slds-theme_error
  }
}
