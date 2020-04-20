var stylesheet = document.styleSheets[2]; // dark-mode stylesheet

$(function(){
    var test = localStorage.input === 'true'? true: false;
    $('#switch').prop('checked', test || false);
    if ($('#switch').is(':checked')) {
      stylesheet.disabled = false;
    }
});

$('#switch').on('change', function() {
    localStorage.input = $(this).is(':checked');
    if ($('#switch').is(':checked')) {
      stylesheet.disabled = false;
    }
    else {
      stylesheet.disabled = true;
    }
});
