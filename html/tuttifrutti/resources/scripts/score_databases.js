/**
 * Created by Olivier Richard (oric.dev@iznogoud.neomailbox.ch) on 30/10/18.
 */

/* SCORE DATABASES */
function fetch_score_databases() {
    var cached_databases = getCachedScoreDatabases();
    if (cached_databases != null) {
        // Default db to use is param score if specified in URL, otherwise first db (holds data to draw the graph as well)
        url_score_db = getParameterByName(URL_PARAM_SCORE, window.location.href);
        if (url_score_db != undefined && url_score_db != "") {
            param_db_for_graph = cached_databases["stats"].filter(function (db) {
                return db[FLD_DB_NICK_NAME].toLowerCase() == url_score_db.toLowerCase();
            });
            if (param_db_for_graph != undefined) {
                current_db_for_graph = param_db_for_graph[0];
            }
        }
        if (current_db_for_graph == undefined) {
            current_db_for_graph = getCachedCurrentDatabase();
        }
        if (current_db_for_graph == undefined) {
            current_db_for_graph = cached_databases["stats"][0];
            //alert("caching default since null");
        }
        cacheCurrentScoreDatabase(current_db_for_graph);
        fillHtmlElementWithDatabases(cached_databases["stats"]);
    }
}

function getCachedScoreDatabases() {
    var key_localstorage_databases = LOCAL_STORAGE_SCORE_DATABASES;
    var databases = JSON.parse(window.localStorage.getItem(key_localstorage_databases));
    if (databases != null) {
        return databases;
    } else {
        var data_score_databases = undefined;
        $.ajax({
            type: "GET",
            url: URL_ROOT_API + ENDPOINT_SCORE_DBS,
            async: false,
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                data_score_databases = filterDatabases(data);
                cacheScoreDatabases(data_score_databases);
            }
        });
        return data_score_databases;
    }
}

function getCachedCurrentDatabase() {
    var key_localstorage_current_db = LOCAL_STORAGE_CURRENT_DATABASE;
    current_db = JSON.parse(window.localStorage.getItem(key_localstorage_current_db));
    return current_db;
}

function filterDatabases(databases) {
    dbs_to_show = databases["stats"].filter(function (db) {
        // Mock for filtering only active dbs for everybody and all dbs for testing purposes
        if (window.location.href.search("/test") >= 0 || db["isActive"] == true) {
            return db;
        }
    });
    databases["stats"] = dbs_to_show;
    return databases;
}

function cacheScoreDatabases(databases) {
    var key_localstorage_databases = LOCAL_STORAGE_SCORE_DATABASES;
    window.localStorage.setItem(key_localstorage_databases, JSON.stringify(databases));
}

function cacheCurrentScoreDatabase(current_db) {
    var key_localstorage_current_db = LOCAL_STORAGE_CURRENT_DATABASE;
    window.localStorage.setItem(key_localstorage_current_db, JSON.stringify(current_db));
}

function changeScoreDb(ctrl) {
    current_db_for_graph = getCachedScoreDatabases()["stats"][ctrl.selectedIndex];
    cacheCurrentScoreDatabase(current_db_for_graph);
}