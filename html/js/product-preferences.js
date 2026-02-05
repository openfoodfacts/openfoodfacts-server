/*global lang */
/*global preferences_text*/ // depends on which type of page the preferences are shown on
/*global default_preferences*/ // depends on flavor: OFF, OBF etc.
/*global product_type */
/*global initializeTagifyInput */

let attribute_groups; // All supported attribute groups and attributes + translated strings
let preferences; // All supported preferences + translated strings
let use_user_product_preferences_for_ranking = JSON.parse(localStorage.getItem('use_user_product_preferences_for_ranking'));
let reset_message;

const staticBaseUri = `${document.location.protocol}//static.${document.querySelector('html').dataset.serverdomain}`;

function get_user_product_preferences() {
    // Retrieve user preferences from local storage

    let user_product_preferences = {};
    const user_product_preferences_string = localStorage.getItem('user_product_preferences');

	if (user_product_preferences_string) {
		user_product_preferences = JSON.parse(user_product_preferences_string);
    } else {
        user_product_preferences = default_preferences;
    }

    return user_product_preferences;
}



if (typeof product_type === 'undefined') { // product_type is not defined
    reset_message = lang().reset_preferences_details_food; // default to food
}
else {
    reset_message = lang()["reset_preferences_details_" + product_type];
}






// display a summary of the selected preferences
// in the order mandatory, very important, important

/* exported display_selected_preferences */

function display_selected_preferences(target_selected_summary, product_preferences) {

    const selected_preference_groups = {
        "mandatory": [],
        "very_important": [],
        "important": [],
    };

    // Iterate over attribute groups
    $.each(attribute_groups, function(key, attribute_group) {

        // Iterate over attributes

        $.each(attribute_group.attributes, function(key, attribute) {

            if ((product_preferences[attribute.id]) && (product_preferences[attribute.id] != "not_important")) {
                const attribute_html = '<li>' + attribute.setting_name + '</li>';
                selected_preference_groups[product_preferences[attribute.id]].push(attribute_html);
            }
        });
    });

    let selected_preferences_html = '';

    $.each(selected_preference_groups, function(selected_preference, selected_preference_group) {

        let selected_preference_name;

        $.each(preferences, function(key, preference) {

            if (selected_preference == preference.id) {
                selected_preference_name = preference.name;
            }
        });

        if (selected_preference_group.length > 0) {
            selected_preferences_html += "<div>" +
                "<strong>" + selected_preference_name + "</strong>" +
                "<ul>" + selected_preference_group.join("") + "</ul>" +
                "</div>";
        }
    });

    // dropdown link to see a preferences summary
    const html = '<a id="preferences_link" data-dropdown="selected_preferences">' +
        lang().see_your_preferences + '</a></p>' +
        '<div id="selected_preferences" data-dropdown-content class="f-dropdown content medium">' +
        selected_preferences_html +
        '</div>';

    $(target_selected_summary).html(html);

    $(document).foundation('reflow');
}


function generate_preferences_switch_button(preferences_text, checkbox_id) {

	let checked = '';
	if (use_user_product_preferences_for_ranking) {
		checked = " checked";
	}

	const html = '<div class="flex-grid direction-row toggle_food_preferences" style="margin-right:2rem;margin-bottom:1rem;align-items: center;">' +
    '<fieldset class="switch round success unmarged" tabindex="0" id="' + checkbox_id +'_switch" style="align-items:center;margin-right:0.5rem;padding-top:0.1rem;padding-bottom:0.1rem;">' +
    '<input class="preferences_checkboxes" id="' + checkbox_id + '" type="checkbox"' + checked + '>' +
    '<label for="' + checkbox_id +'" class="h-space-tiny" style="margin-top:0"></label></fieldset>' +
    '<label for="' + checkbox_id +'" class="v-space-tiny h-space-tiny" style="margin-top:0">' + preferences_text + '</label></div>';

	return html;
}


function activate_preferences_switch_buttons(change) {

	$(".preferences_checkboxes").change(function() {

		localStorage.setItem('use_user_product_preferences_for_ranking', this.checked);
		use_user_product_preferences_for_ranking = this.checked;

		// Update the other checkbox value
		$(".preferences_checkboxes").prop('checked',use_user_product_preferences_for_ranking);

		// Call the change callback if we have one (e.g. to update search results)
		if (change) {
			change();
		}
	});
}

// set a cookie with a name, value and expiration in days
function setCookie(name, value, days) {
    let expires = "";
    if (days) {
        const date = new Date();
        date.setTime(date.getTime() + (days*24*60*60*1000));
        expires = "; expires=" + date.toUTCString();
    }
    document.cookie = name + "=" + (encodeURIComponent(value) || "")  + expires + "; path=/";
}

// callback function when the unwanted ingredients input field is changed
function unwanted_ingredients_change_callback(e) {
    let values_json = e.tagifyValue;
    // If tagifyValue is empty and value is not an array and is a non-empty string, it is an initial call to initialize tagify, ignore it
    if ((!values_json || values_json.length == 0) && (!Array.isArray(e.value) && e.value && e.value.length > 0)) {
        return;
    }
    // The tagifyValue is a string like: [{"value":"Amidon de patate douce"},{"value":"test"}]
    // Turn it into a comma separated string
    // If the JSON is an empty string, turn it to an empty array
    if (!values_json || values_json.length == 0) {
        values_json = "[]";
    }
    const values_string = JSON.parse(values_json).map(function(v) {
        return v.value;
    }).join(", ");

    // If there are no unwanted ingredients, remove the local storage item and cookie
    if (values_string.length == 0) {
        localStorage.removeItem('attribute_unwanted_ingredients_tags');
        setCookie('attribute_unwanted_ingredients_tags', '', -1); // delete the cookie

        // Also change the value of the unwanted_ingredients radio button to not_important if it is not already
        if ($("input[name='unwanted_ingredients']:checked").val() != "not_important") {
            $("input[name='unwanted_ingredients'][value='not_important']").prop("checked", true).trigger("change");
        }
    }
    else
    {
        // Call the /api/v3/taxonomy_canonicalize_tags API to get the canonical tags for the entered ingredient names
        $.ajax({
            url: "/api/v3/taxonomy_canonicalize_tags?tagtype=ingredients&local_tags_list=" + encodeURIComponent(values_string),
            type: "GET",
            dataType: "json",
            success: function(data) {
                const canonical_tags_list = data.canonical_tags_list;
                // store the entered ingredient names in local storage
                // Note: local storage is subdomain specific, so it will be different for each country / language subdomain
                // It is already the case for the other preferences settings
                localStorage.setItem('attribute_unwanted_ingredients_tags', canonical_tags_list);
                // also set a cookie so that the server can access it when rendering product pages and product list pages
                setCookie('attribute_unwanted_ingredients_tags', canonical_tags_list, 3650); // 10 years
            }
        });

        // If the unwanted_ingredients attribute is currently set to not_important, change it to important
        if ($("input[name='unwanted_ingredients']:checked").val() == "not_important") {
            $("input[name='unwanted_ingredients'][value='important']").prop("checked", true).trigger("change");
        }
    }

    // Ideally we should find a way to call the change callback to update search results attributes
    // if unwanted ingredients are changed, but it's not easy to pass the change callback to this function
}

// initialize the Tagify autocomplete suggestions on the unwanted ingredients input field
function initialize_unwanted_ingredients_tagify() {

    const input = document.querySelector('input[name=attribute_unwanted_ingredients_names]');
    // initialize Tagify on the input field using the autocomplete URL from the data-autocomplete attribute
    // we use the initializeTagifyInput function from tagify-init.js
    // as it does a lot of things to handle suggestions, synonyms etc.
    // We pass 0 as maximumRecentEntriesPerTag to avoid storing recent entries

    initializeTagifyInput(input, 0, unwanted_ingredients_change_callback);
}

// Populate the input field for unwanted ingredients and initialize tagify on it
// As it calls several JS, CSS and APIs, we do it only when the preferences form is shown
let unwanted_ingredients_preferences_initalized = false;
let attribute_unwanted_ingredients_enabled = false;

// We also want to turn the canonical ingredient tags list into local ingredient names
// using the /api/v3/taxonomy_display_tags API
function localize_unwanted_ingredients_tags() {

    return new Promise(function(resolve, reject) {
        const tags = localStorage.getItem('attribute_unwanted_ingredients_tags');
        if (tags && tags.length > 0) {
            $.ajax({
                url: "/api/v3/taxonomy_display_tags?tagtype=ingredients&canonical_tags_list=" + encodeURIComponent(tags),
                type: "GET",
                dataType: "json",
                success: function(data) {
                    const local_tags_list = data.local_tags_list;
                    // store the local ingredient names in the input field
                    $('input[name=attribute_unwanted_ingredients_names]').val(local_tags_list);
                    resolve();
                },
                error: function(jqxhr, status, exception) {
                    reject(exception);
                }
            });
        }
        else {
            resolve();
        }
    });
}

function display_unwanted_ingredients_preferences() {

    if (unwanted_ingredients_preferences_initalized) {
        return;
    }

    // Initialize tagify on the unwanted ingredients input field if we have it
    if (attribute_unwanted_ingredients_enabled) {
        // We need to load tagify library if not already loaded
        if (globalThis.Tagify === undefined) {
            // Load tagify JS and CSS
            // We use jQuery to load the CSS file dynamically
            $.when(
                $.getScript(`${staticBaseUri}/js/dist/tagify.js`),
                $.getScript(`${staticBaseUri}/js/dist/tagify-init.js`),
                localize_unwanted_ingredients_tags()
            ).done(function() {
                // Initialize tagify on the unwanted ingredients input field
                initialize_unwanted_ingredients_tagify();
            }).fail(function(jqxhr, settings, exception) {
                console.error("Error loading tagify JS or CSS:", exception);
            });
        }
        else {
            initialize_unwanted_ingredients_tagify();
        }
    }

    unwanted_ingredients_preferences_initalized = true;
}

// display_user_product_preferences can be called by other scripts
/* exported display_user_product_preferences */

// Make sure we display the preferences only once when we have both preferences and attribute_groups loaded
let displayed_user_product_preferences = false;

function display_user_product_preferences(target_selected, target_selection_form, change) {

  if (attribute_groups) {
    // continue
  } else {
    $.getJSON("/api/v3.4/attribute_groups", function (data) {
      attribute_groups = data.attribute_groups;
      display_user_product_preferences(target_selected, target_selection_form, change);
    });

    return;
  }

  if (preferences) {
    // continue
  } else {
    $.getJSON("/api/v3.4/preferences", function (data) {
      preferences = data.preferences;
      display_user_product_preferences(target_selected, target_selection_form, change);
    });

    return;
  }

  if (attribute_groups && preferences && !displayed_user_product_preferences) {
    displayed_user_product_preferences = true;

    let user_product_preferences = get_user_product_preferences();
    const attribute_groups_html = [];

    $.each(attribute_groups, function (key, attribute_group) {
      let attribute_group_html =
        "<li id='attribute_group_" + attribute_group.id + "' class='attribute_group accordion-navigation'>" +
        "<a href='#attribute_group_" + attribute_group.id + "_a' style='color:black;'>" +
        "<span class='attribute_group_name'>" + attribute_group.name + "</span></a>" +
        "<div id='attribute_group_" + attribute_group.id + "_a' class='content active'>";

      if (attribute_group.warning) {
        attribute_group_html += "<div class='alert-box warning attribute_group_warning'>" + attribute_group.warning + "</div>";
      }

      attribute_group_html += "<ul style='list-style-type: none'>";

      $.each(attribute_group.attributes, function (akey, attribute) {
        let attribute_name_and_parameters_html = "";

        if (attribute.id === "unwanted_ingredients") {
          attribute_unwanted_ingredients_enabled = true;
          attribute_name_and_parameters_html =
            '<div style="display: flex; flex-direction: column; align-items: flex-start;width: 100%;">' +
              '<label for="attribute_unwanted_ingredients_names">' +
                "<span class='attribute_name' style=\"margin-bottom: 0.5rem;\">" + attribute.setting_name + "</span>" +
              "</label>" +
              '<input type="text" name="attribute_unwanted_ingredients_names" id="attribute_unwanted_ingredients_names" ' +
                'class="text" ' +
                'placeholder="Enter ingredients you cannot or do not want to eat" ' +
                'value="" ' +
                'data-autocomplete="/api/v3/taxonomy_suggestions?tagtype=ingredients" ' +
                'style="width: 100%;"/>' +
            "</div>";
        } else {
          attribute_name_and_parameters_html = "<span class='attribute_name'>" + attribute.setting_name + "</span>";
        }

        attribute_group_html +=
          "<li id='attribute_" + attribute.id + "' class='attribute'>" +
          "<fieldset class='fieldset_attribute_group' style='margin:0;padding:0;border:none'>" +
          "<div class='attribute_img'><div style='width:96px;float:left;margin-right:1em;'><img src='" + attribute.icon_url + "' class='match_icons' alt=''></div>" +
          attribute_name_and_parameters_html +
          "</div>" +
          "<div class='attribute_group'>";

        $.each(preferences, function (pkey, preference) {
          let checked = "";
          if (
            (!user_product_preferences[attribute.id] && preference.id === "not_important") ||
            (user_product_preferences[attribute.id] === preference.id)
          ) {
            checked = " checked";
          }

          attribute_group_html +=
            "<div class='attribute_item'><input class='attribute_radio' id='attribute_" + attribute.id + "_" + preference.id +
            "' value='" + preference.id + "' type='radio' name='" + attribute.id + "'" + checked + ">" +
            "<label for='attribute_" + attribute.id + "_" + preference.id + "'>" + preference.name + "</label></input></div>";
        });

        if (attribute.description_short) {
          attribute_group_html += "<p class='attribute_description_short'>" + attribute.description_short + "</p>";
        }

        attribute_group_html += "<hr style='clear:left;border:none;margin:0;margin-bottom:0.5rem;padding:0;'>";
        attribute_group_html += "</div></fieldset></li>";
      });

      attribute_group_html += "</ul></div></li>";
      attribute_groups_html.push(attribute_group_html);
    });

    $(target_selection_form).html(
      '<div class="panel callout">' +
        '<div class="edit_button close_food_preferences">' +
          '<a class="show_selected button small success round" role="button" tabindex="0">' +
            '<img src="/images/icons/dist/cancel.svg" class="icon" alt="" style="filter:invert(1)">' +
            " " + lang().close +
          "</a>" +
        "</div>" +
        "<h2>" + lang().preferences_edit_your_preferences + "</h2>" +
        "<p>" + lang().preferences_locally_saved + "</p>" +
        generate_preferences_switch_button(lang().classify_products_according_to_your_preferences, "preferences_switch_in_preferences") +
        '<a id="reset_preferences_button" class="button small round success" role="button" tabindex="0">' + lang().reset_preferences + "</a>" +
        " " + reset_message +
        '<ul id="user_product_preferences" class="accordion" data-accordion>' +
          attribute_groups_html.join("") +
        "</ul>" +
        "<br><br>" +
        '<div class="edit_button close_food_preferences">' +
          '<a class="show_selected button small round success" role="button" tabindex="0">' +
            '<img src="/images/icons/dist/cancel.svg" class="icon" alt="" style="filter:invert(1)">' +
            " " + lang().close +
          "</a>" +
        "</div><br><br>" +
      "</div>"
    );

    $(".attribute_radio"
      ).off("change.pref"
      ).on("change.pref", function () {
        if (this.checked) {
          user_product_preferences[this.name] = $("input[name='" + this.name + "']:checked").val();
          localStorage.setItem("user_product_preferences", JSON.stringify(user_product_preferences));

          display_use_preferences_switch_and_edit_preferences_button(
            target_selected,
            target_selection_form,
            change
          );

          if (change) {
            change();
          }
        }
      });

    if (target_selected) {
      display_use_preferences_switch_and_edit_preferences_button(target_selected, target_selection_form, change);
    }

    $("#reset_preferences_button"
      ).off("click.pref"
      ).on("click.pref", function () {
        user_product_preferences = default_preferences;
        localStorage.setItem("user_product_preferences", JSON.stringify(user_product_preferences));
        // force rebuild
        displayed_user_product_preferences = false;
        display_user_product_preferences(target_selected, target_selection_form, change);
        if (change) {
          change();
        }
      });

    $("#reset_preferences_button"
      ).off("keydown.pref"
      ).on("keydown.pref", function (event) {
        if (event.key === "Space" || event.key === "Enter") {
          $("#reset_preferences_button").trigger("click.pref");
        }
      });

    $(".show_selected"
      ).off("click.prefclose"
      ).on("click.prefclose", function () {
        $(target_selection_form).hide();
        $(target_selected).show();
        display_use_preferences_switch_and_edit_preferences_button(target_selected, target_selection_form, change);
      });

    $(".show_selected"
      ).off("keydown.prefclose"
      ).on("keydown.prefclose", function (event) {
        if (event.key === "Space" || event.key === "Enter") {
          $(".show_selected").trigger("click.prefclose");
        }
      });

    $("#user_product_preferences").foundation();
    $(document).foundation("equalizer", "reflow");
  }
}

/* eslint func-style: ["error", "declaration", { "allowArrowFunctions": true }] */

function display_use_preferences_switch_and_edit_preferences_button(target_selected, target_selection_form, change) {
  const html_edit_preferences =
    '<div><a id="show_selection_form" class="button small round secondary" role="button" tabindex="0" style="display:inline-flex;align-items:center;gap:.35rem">' +
      '<span class="material-icons size-20">&#xE556;</span>' +
      '<span>' + lang().preferences_edit_your_preferences + '</span>' +
    '</a></div>';

  const html_external_sources_button =
    '<div><a id="show_external_sources" class="button small round secondary" role="button" tabindex="0" style="display:inline-flex;align-items:center;gap:.35rem;margin-left:.5rem">' +
      '<span class="material-icons size-20">tune</span>' +
      '<span>' + (lang().external_sources || "External sources") + '</span>' +
    '</a></div>';

  const html_external_sources =
    '<span id="external_sources_btn_wrap">' + html_external_sources_button + '</span>';

  const html =
    generate_preferences_switch_button(preferences_text, "preferences_switch_in_list_of_products") +
    html_edit_preferences +
    html_external_sources;

  $(target_selected).html(html);
  activate_preferences_switch_buttons(change);

  (function decideExternalBtnVisibility() {
    function hideBtn() {
      document.getElementById("external_sources_btn_wrap")?.remove();
    }

    function decide() {
      if (typeof globalThis.hasAnyScoppablePanels !== "function") {
        hideBtn();

        return;
      }
      globalThis.hasAnyScoppablePanels().then(
        function(hasAny) {
          if (!hasAny) {
            hideBtn();
          }
        }).catch(
          function() {
            hideBtn();
        });
    }

    if (typeof globalThis.hasAnyScoppablePanels === "function") {
      decide();
    } else {
      const script = document.createElement("script");
      script.src = `${staticBaseUri}/js/dist/external-knowledge-panels.js`;
      script.onload = decide;
      document.body.appendChild(script);
    }
  })();

  $("#show_selection_form"
    ).off(".prefopen"
    ).on("click.prefopen", function () {
      const hasPrefsPanel = $(target_selection_form).find("#user_product_preferences").length > 0;

      if (!hasPrefsPanel) {
        if (displayed_user_product_preferences !== undefined) {
          displayed_user_product_preferences = false;
        }
        display_user_product_preferences(target_selected, target_selection_form, change);
      }

      if (typeof display_unwanted_ingredients_preferences === "function") {
        display_unwanted_ingredients_preferences();
      }

      $(target_selected).hide();
      $(target_selection_form).show();
      $(document).foundation("equalizer", "reflow");
    });

  $("#show_selection_form").off(
      "keydown.prefopen"
    ).on(
      "keydown.prefopen", function (e) {
        if (e.key === "Space" || e.key === "Enter") {
          $("#show_selection_form").trigger("click.prefopen");
        }
      });

  $("#show_external_sources"
    ).off(".extsrc"
    ).on("click.extsrc", function () {
      $(target_selected).hide();

      const wrapper =
        '<div class="panel callout" id="external_sources_panel">' +
          '<div class="edit_button close_food_preferences">' +
            '<a class="show_selected button small success round" role="button" tabindex="0" style="display:inline-flex;align-items:center;gap:.35rem">' +
              '<img src="/images/icons/dist/cancel.svg" class="icon" alt="" style="filter:invert(1)">' +
              ' ' + lang().close +
            '</a>' +
          '</div>' +
          '<h2 style="margin-bottom:1rem;">' + (lang().external_sources || "External sources") + '</h2>' +
          '<div id="external_panels_prefs" class="v-space-small"></div>' +
        '</div>';

      $(target_selection_form).html(wrapper).show();

      function mount() {
        if (globalThis.renderExternalPanelsOptinPreferences) {
          const el = document.getElementById("external_panels_prefs");
          globalThis.renderExternalPanelsOptinPreferences(el);
        }
      }

      if (globalThis.renderExternalPanelsOptinPreferences) {
        mount();
      } else {
        const s = document.createElement("script");
        s.src = `${staticBaseUri}/js/dist/external-knowledge-panels.js`;
        s.onload = mount;
        document.body.appendChild(s);
      }

      $(".show_selected"
        ).off(".extsrcclose"
        ).on("click.extsrcclose", function () {
          $(target_selection_form).hide();
          $(target_selected).show();
          display_use_preferences_switch_and_edit_preferences_button(
            target_selected,
            target_selection_form,
            change
          );
        });

      $(".show_selected"
        ).off("keydown.extsrcclose"
        ).on("keydown.extsrcclose", function (e) {
          if (e.key === "Space" || e.key === "Enter") {
            $(".show_selected").trigger("click.extsrcclose");
          }
        });
    });
}
