class YouTubePage {
    get searchBox() { return $('[name="search_query"]'); }
    get searchButton() { return $('#search-icon-legacy'); }
    get firstVideo() { return $('(//a[@id="video-title"])[1]'); }

    async open() {
        await browser.url('https://www.youtube.com');
    }

    async search(videoTitle) {
        await this.searchBox.setValue(videoTitle);
        await this.searchButton.click();
        await browser.pause(3000);
    }

    async playFirstVideo() {
        await this.firstVideo.click();
        await browser.pause(5000);
    }
}

module.exports = new YouTubePage();
a