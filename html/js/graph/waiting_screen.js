/* got from https://stackoverflow.com/questions/9152416/javascript-how-to-block-the-whole-screen-while-waiting-for-ajax-response */

function block_screen(msg) {
    /*$('<div id="screenBlock">' +
     '<img width="48px" src="{{ url_for(\'static\',filename=\'images/giphy5.gif\') }}"'+
     ' title="server busy"/></div>').appendTo('body');*/
    $('#screenBlock').empty();
    $('#screenBlock').append("<p>" + msg + "</p>");
    $('#screenBlock').css({opacity: 0, width: $(document).width(), height: $(document).height()});
    $('#screenBlock').addClass('blockDiv');
    $('#screenBlock').show();
    $('#screenBlock').animate({opacity: 0.85}, 100);
}

function unblock_screen() {
    $('#screenBlock').animate({opacity: 0}, 100, function () {
        $('#screenBlock').hide();
    });
}


