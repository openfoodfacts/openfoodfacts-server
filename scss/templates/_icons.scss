@font-face {
	font-family: "<%= fontName %>";
	src: url('<%= fontPath %><%= fontName %>.eot<%= cacheBusterQueryString %>');
	src: url('<%= fontPath %><%= fontName %>.eot?<%= cacheBuster %>#iefix') format('eot'),
		url('<%= fontPath %><%= fontName %>.woff2<%= cacheBusterQueryString %>') format('woff2'),
		url('<%= fontPath %><%= fontName %>.woff<%= cacheBusterQueryString %>') format('woff'),
		url('<%= fontPath %><%= fontName %>.ttf<%= cacheBusterQueryString %>') format('truetype'),
		url('<%= fontPath %><%= fontName %>.svg<%= cacheBusterQueryString %>#<%= fontName %>') format('svg');
}

@mixin <%= cssClass%>-styles {
	font-family: "<%= fontName %>";
		-webkit-font-smoothing: antialiased;
		-moz-osx-font-smoothing: grayscale;
	font-style: normal;
	font-variant: normal;
	font-weight: normal;
	// speak: none; // only necessary if not using the private unicode range (firstGlyph option)
	text-decoration: none;
	text-transform: none;
}

%<%= cssClass%> {
	@include <%= cssClass%>-styles;
}

@function <%= cssClass%>-char($filename) {
	$char: "";
<% _.each(glyphs, function(glyph) { %>
	@if $filename == <%= glyph.fileName %> {
		$char: "\<%= glyph.codePoint %>";
	}<% }); %>

	@return $char;
}

@mixin <%= cssClass%>($filename, $insert: before, $extend: true) {
	&:#{$insert} {
		@if $extend {
			@extend %<%= cssClass%>;
		} @else {
			@include <%= cssClass%>-styles;
		}
		content: <%= cssClass%>-char($filename);
	}
}

<% _.each(glyphs, function(glyph) { %>.<%= cssClass%>-<%= glyph.fileName %> {
	@include <%= cssClass%>(<%= glyph.originalFileName ? glyph.originalFileName : glyph.fileName %>);
}
<% }); %>
