document.addEventListener('DOMContentLoaded', function() {

    var StickyNav = new hcSticky('.topbarsticky', {
        stickTo: '#main_container'
    });
    var StickyNavProd = new hcSticky('.prod-nav', {
        stickTo: '#main_column',
        followScroll: false,
        responsive: {
            1023: {
                top: -20
            },
            731: {
                top: 40
            },
        }
    });
    //StickyNav.update({
    //top: 20
    //});
});
