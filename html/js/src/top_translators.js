// This file is part of Product Opener.
// 
// Product Opener
// Copyright (C) 2011-2018 Association Open Food Facts
// Contact: contact@openfoodfacts.org
// Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
// 
// Product Opener is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
// 
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import 'jquery';
import './vendor/datatables.js';
import 'papaparse';

function initTranslatorTable(url, id) {
    var dataSource = [];

    Papa.parse(url, {
        download: true,
        delimiter: ",",
        header: true,
        dynamicTyping: true,
        skipEmptyLines: true,
        withCredentials: false,
        step: function(results, parser) {
            dataSource = dataSource.concat(results.data);
            console.log("Row data:", results.data);
            console.log("Row errors:", results.errors);
        },
        complete: function () {
            $(id).DataTable({
                "data": dataSource,
                "columns": [
                    { "data": "Name" },
                    { "data": "Translated (Words)" },
                    { "data": "Target Words" },
                    { "data": "Approved (Words)" },
                    { "data": "Votes Made" }
                ],
                "order": [[ 1, "desc" ]],
                "paging": false,
                "info": false,
                "searching": false
            });
        }
    });
}