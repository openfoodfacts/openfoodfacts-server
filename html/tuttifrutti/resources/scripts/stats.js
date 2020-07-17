/**
 * Created by Olivier Richard (oric.dev@iznogoud.neomailbox.ch) on 19/10/18.
 */

function displayStats() {
    $.ajax({
        type: "GET",
        url: $SCRIPT_ROOT + ENDPOINT_SCORE_DBS,
        contentType: "application/json; charset=utf-8",
        success: function (db_stats) {
            img_productve = "<img src='/static/images/Symbol_OK.svg' class='img_status' alt='database is productive' title='database is productive' />";
            img_in_progress = "<img src='/static/images/busy.gif' class='img_status' alt='database is being built for next release' title='database is being built for next release' />";
            img_warning = "<img src='/static/images/Icon_Simple_Warn.png' class='img_status' alt='unsafe statistics' title='unsafe statistics' />";

            // Show timestamp of stats-file
            $(ID_FILE_TIMESTAMP).append(db_stats["datefile"]);

            db_stats["stats"].forEach(function (db, index) {
                //$(ID_TABLE_STATS).appendChild("tr").appendChild("td").nodeValue(db[FLD_DB_NICK_NAME]);
                line_tr = "<tr>";
                /* define status of db:
                 * - green: production
                 * - wheels: being built
                 * - warning sign in case of error while computing stats nightly (exception, etc.)
                 */
                if (db[FLD_IS_ERROR] == true) {
                    line_tr += "<td>" + img_warning + "</td>";
                } else if (db[FLD_IS_ACTIVE] == true) {
                    line_tr += "<td>" + img_productve + "</td>";
                } else {
                    line_tr += "<td>" + img_in_progress + "</td>";
                }
                line_tr += "<td class='nickname'>" + db[FLD_DB_NICK_NAME] + "</td>" +
                    "<td>" + db[FLD_DB_NAME] + "</td>";

                // owner with email
                if (db[FLD_EMAIL_OWNER] != undefined && db[FLD_EMAIL_OWNER] != "") {
                    line_tr += "<td><a href='mailto:" + db[FLD_EMAIL_OWNER] +
                        "?subject=" + db[FLD_DB_NICK_NAME] + "' title='send email to the owner of the database'>" + db[FLD_OWNER] + "</a></td>";
                } else {
                    line_tr += "<td>" + db[FLD_OWNER] + "</td>";
                }

                // info: summary and descriptions
                img_summary = "<img src='/static/images/info_summary.png' class='img_info' title='SUMMARY: " + db[FLD_DB_SUMMARY] + "' />";
                full_description = db[FLD_DB_DESCRIPTION_EN];
                if (db[FLD_DB_DESCRIPTION] != undefined && db[FLD_DB_DESCRIPTION] != "") {
                    full_description += " // " + db[FLD_DB_DESCRIPTION];
                }
                img_description = "<img src='/static/images/info_details.png' class='img_info' title='DESCRIPTION: " + full_description + "' />";
                line_tr += "<td>" + img_summary + "</td>";
                line_tr += "<td>" + img_description + "</td>";

                nb_intersect_computed = 0;
                if (db[FLD_NB_PRODUCTS_EXTRACTED] != undefined && db[FLD_PROGRESSION] != undefined) {
                    nb_intersect_computed = Math.round((db[FLD_NB_PRODUCTS_EXTRACTED] * (db[FLD_NB_PRODUCTS_EXTRACTED] - 1)) / 100 * db[FLD_PROGRESSION]);
                }
                line_tr +=
                    "<td class='a_right'>" + formatNumbers(db[FLD_DB_MAX_SIZE], 1) + "</td>" +
                    "<td class='a_right'>" + formatNumbers(db[FLD_DB_SIZE_GB], 3) + "</td>" +
                    "<td class='a_right'>" + formatNumbers(db[FLD_PROGRESSION], 3) + "</td>" +
                    "<td class='a_right'>" + formatNumbers(db[FLD_NB_PRODUCTS_EXTRACTED]) + "</td>" +
                    "<td class='a_right'>" + formatNumbers(nb_intersect_computed) + "</td>" +
                    "<td class='a_right'>" + formatNumbers(db[FLD_SIMILARITY_MIN_PERCENTAGE]) + "</td>" +
                    "<td class='a_right'>" + formatNumbers(db[FLD_NB_PRODUCTS]) + "</td>" +
                    "<td class='a_right'>" + formatNumbers(db[FLD_NB_INTERSECTIONS]) + "</td>";
                if (db[FLD_LINK_CI] == undefined || db[FLD_LINK_CI] == "") {
                    line_tr += "<td class='a_center'>-</td>";
                } else {
                    line_tr += "<td class='a_center'><a href='" + db[FLD_LINK_CI] + "' target='_blank' alt='ComputingInstance.java' title='access to ComputingInstance.java file used to build this database'>" +
                        "link</a></td>";
                }

                line_tr += "<td class='a_center'><a href='" + db[FLD_LINK_STATS_PROSIM] + "' target='_blank' alt='stats reports on PROSIM blog' title='statistics reports for this database are available on the PROSIM blog'>" +
                    "link</a></td>" +
                    "</tr>";
                $(ID_TABLE_STATS + " tr:last").after(line_tr);

            });
        }
    });

}

/*
 nb_decimals defaults to 0
 */
function formatNumbers(numb, nb_decimals) {
    if (numb == undefined) {
        return "-";
    }
    if (Math.ceil(numb) === 0) {
        return "-";
    }

    if (nb_decimals == undefined) {
        nb_decimals = 0;
    }
    if (nb_decimals > 0) {
        // truncate decimals
        numb = Math.floor(numb * (Math.pow(10, nb_decimals))) / Math.pow(10, nb_decimals);
    }
    // add spaces each 3 digits: decide which function to use
    if (numb.toString().search('.') >= 0) {
        numb = numberWithSpacesFloats(numb);
    } else {
        numb = numberWithSpacesIntegers(numb);
    }
    return numb;
}

/* load stats when page is ready */
$(document).ready(displayStats);
