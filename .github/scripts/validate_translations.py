#!/usr/bin/env python3
import os
import re
import sys
import glob
import urllib.request

BRAND_TERMS = [
    "Open Food Facts",
    "Open Beauty Facts",
    "Open Pet Food Facts",
    "Open Prices",
    "Green-Score",
    "Nutri-Score",
    "Eco-Score",
    "NOVA"
]

PLAYSTORE_LOCALES = {
    "af": "Afrikaans", "sq": "Albanian", "ar": "Arabic-Saudi-Arabia", "hy": "Armenian",
    "az": "Azerbaijani", "bn": "Bangla", "eu": "Basque", "be": "Belarusian",
    "bs": "Bosnian", "bg": "Bulgarian", "my": "Burmese", "ca": "Catalan",
    "zh": "Chinese-China", "zh_cn": "Chinese-China", "zh_hans": "Chinese-China",
    "zh_hk": "Chinese-Hong-Kong", "zh_tw": "Chinese-Taiwan", "zh_hant": "Chinese-Taiwan",
    "hr": "Croatian", "cs": "Czech", "da": "Danish", "nl": "Dutch", "nl_be": "Dutch",
    "nl_nl": "Dutch", "et": "Estonian", "fil": "Filipino", "tl": "Filipino", "fi": "Finnish",
    "fr_ca": "French-CA", "fr": "French", "gl": "Galician", "ka": "Georgian",
    "de": "German", "el": "Greek", "gu": "Gujarati", "he": "Hebrew", "iw": "Hebrew",
    "hi": "Hindi", "hu": "Hungarian", "is": "Icelandic", "id": "Indonesian",
    "ga": "Irish", "it": "Italian", "ja": "Japanese", "kn": "Kannada", "kk": "Kazakh",
    "km": "Khmer", "ko": "Korean", "ky": "Kyrgyz", "lo": "Lao", "lv": "Latvian",
    "lt": "Lithuanian", "mk": "Macedonian", "ml": "Malayalam", "ms": "Malaysian",
    "mr": "Marathi", "mn": "Mongolian", "ne": "Nepali", "no": "Norwegian",
    "nb": "Norwegian", "nn": "Norwegian", "fa": "Persian", "pl": "Polish",
    "pt_br": "Portuguese-Brazil", "pt": "Portuguese-Portugal", "pt_pt": "Portuguese-Portugal",
    "pa": "Punjabi", "ro": "Romanian", "ru": "Russian", "sr": "Serbian",
    "sr_cs": "Serbian", "sr_rs": "Serbian", "si": "Sinhalese", "sk": "Slovak",
    "sl": "Slovenian", "es": "Spanish", "es_419": "Spanish-LATAM", "sw": "Swahili",
    "sv": "Swedish", "ta": "Tamil", "te": "Telugu", "th": "Thai", "tr": "Turkish",
    "uk": "Ukranian", "ur": "Urdu", "uz": "Uzbek", "vi": "Vietnamese", "zu": "Zulu"
}

def parse_po(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    entries = []
    current_msgctxt = ""
    current_msgid = ""
    current_msgstr = ""
    state = None
    
    for line in lines:
        if line.startswith("msgctxt "):
            if state == "msgstr" and current_msgid != "":
                entries.append((current_msgctxt, current_msgid, current_msgstr))
                current_msgctxt = ""
                current_msgid = ""
                current_msgstr = ""
            state = "msgctxt"
            current_msgctxt = line[len("msgctxt "):].strip(' "\n')
        elif line.startswith("msgid "):
            if state == "msgstr" and current_msgid != "":
                entries.append((current_msgctxt, current_msgid, current_msgstr))
                current_msgctxt = ""
                current_msgid = ""
                current_msgstr = ""
            state = "msgid"
            current_msgid = line[len("msgid "):].strip(' "\n')
        elif line.startswith("msgstr "):
            state = "msgstr"
            current_msgstr = line[len("msgstr "):].strip(' "\n')
        elif line.startswith('"') and state == "msgctxt":
            current_msgctxt += line.strip(' "\n')
        elif line.startswith('"') and state == "msgid":
            current_msgid += line.strip(' "\n')
        elif line.startswith('"') and state == "msgstr":
            current_msgstr += line.strip(' "\n')
        elif line.strip() == "" and state == "msgstr":
            if current_msgid != "":
                entries.append((current_msgctxt, current_msgid, current_msgstr))
            current_msgctxt = ""
            current_msgid = ""
            current_msgstr = ""
            state = None
    
    if state == "msgstr" and current_msgid != "":
        entries.append((current_msgctxt, current_msgid, current_msgstr))
        
    return entries

def check_url_exists(url):
    try:
        req = urllib.request.Request(url, method='HEAD')
        req.add_header('User-Agent', 'Mozilla/5.0 (compatible; TranslationValidator/1.0)')
        with urllib.request.urlopen(req, timeout=2) as response:
            return response.status < 400
    except:
        return False

def check_image_exists(img_ref):
    rel = img_ref
    if rel.startswith("https://static.openfoodfacts.org/"):
        rel = rel[len("https://static.openfoodfacts.org/"):]
    elif rel.startswith("http://static.openfoodfacts.org/"):
        rel = rel[len("http://static.openfoodfacts.org/"):]
    elif rel.startswith("//static.openfoodfacts.org/"):
        rel = rel[len("//static.openfoodfacts.org/"):]

    if rel.startswith("/"):
        rel = rel.lstrip("/")

    local_path = os.path.join("html", rel)
    if os.path.exists(local_path):
        return True

    # If it's an external remote URL, check via network
    if img_ref.startswith("http://") or img_ref.startswith("https://"):
        return check_url_exists(img_ref)

    return False

def extract_placeholders(text):
    c_style = re.findall(r'%[0-9]*\$?[sd]', text)
    html_tags = re.findall(r'</?[a-zA-Z0-9]+[^>]*>', text)
    brackets = re.findall(r'\{[^}]+\}|%\([^)]+\)s', text)
    return sorted(c_style + html_tags + brackets)

def check_po_files():
    brand_issues = []
    url_issues = []
    image_issues = []
    placeholder_issues = []
    badge_issues = []
    
    for po_file in glob.glob("po/**/*.po", recursive=True):
        if 'en.po' in po_file: continue
        locale = os.path.basename(po_file).replace(".po", "")
        url_locale = locale.split("_")[0].lower()
        if locale.lower() in ['zh_hk', 'zh_tw']:
            url_locale = 'zh'
        
        entries = parse_po(po_file)
        for msgctxt, msgid, msgstr in entries:
            # Check Google Play badge localization (even if untranslated / msgstr is empty)
            if msgctxt == "android_app_icon_url":
                badge_val = msgstr if msgstr else msgid
                loc_key = locale.lower()
                expected_lang = PLAYSTORE_LOCALES.get(loc_key) or PLAYSTORE_LOCALES.get(loc_key.split("_")[0])
                if expected_lang and "English" in badge_val and not loc_key.startswith("en"):
                    badge_issues.append(
                        f"- **Unlocalized Google Play badge** in `{po_file}`: uses English badge (`{badge_val}`) but localized badge exists for `{expected_lang}`."
                    )

            if not msgstr: continue
            
            # Check brands
            for brand in BRAND_TERMS:
                if brand in msgid and brand not in msgstr:
                    if len(msgstr) > 0:
                        brand_issues.append(f"- **{brand}** in `{po_file}`: translated as `{msgstr}` (should not be translated)")
            
            # Check placeholders
            id_placeholders = extract_placeholders(msgid)
            str_placeholders = extract_placeholders(msgstr)
            if id_placeholders != str_placeholders:
                placeholder_issues.append(f"- **Placeholder mismatch** in `{po_file}`: Expected `{id_placeholders}`, found `{str_placeholders}` in `{msgstr}`")
            
            # Check URL consistency
            if "world.openfoodfacts.org" in msgid:
                if "world.openfoodfacts.org" in msgstr:
                    url_issues.append(f"- **URL not localized** in `{po_file}`: expected `{url_locale}.openfoodfacts.org` or `world-{url_locale}.openfoodfacts.org`, but found `world.openfoodfacts.org`")
            
            # Check images resolve (both static.openfoodfacts.org URLs and local relative paths)
            img_urls = re.findall(r'(https?://static\.openfoodfacts\.org/[^\s\"\'>]+(?:svg|png|jpg))', msgstr)
            for img in img_urls:
                if not check_image_exists(img):
                    image_issues.append(f"- **Image does not resolve** in `{po_file}`: `{img}` returns 404.")
            
            # Check relative image paths in msgstr or image entries
            is_image_entry = (
                msgctxt in ("android_app_icon_url", "app_store_app_icon_url", "fdroid_app_icon_url") or
                any(msgid.endswith(ext) for ext in ('.svg', '.png', '.jpg', '.jpeg', '.webp', '.gif'))
            )
            if is_image_entry and not msgstr.startswith(('http://', 'https://', '//')):
                if not check_image_exists(msgstr):
                    image_issues.append(f"- **Image does not resolve** in `{po_file}`: `{msgstr}` not found.")
            else:
                clean_str = re.sub(r'https?://[^\s\"\'>]+', '', msgstr)
                rel_imgs = re.findall(r'(/images/[^\s\"\'>]+(?:\.svg|\.png|\.jpg|\.jpeg|\.webp|\.gif))', clean_str)
                for img in rel_imgs:
                    if not check_image_exists(img):
                        image_issues.append(f"- **Local image does not resolve** in `{po_file}`: `{img}` not found.")
                
    return brand_issues, url_issues, image_issues, placeholder_issues, badge_issues

def check_html_files():
    brand_issues = []
    for html_file in glob.glob("html/donate/*.html"):
        if 'en.html' in html_file: continue
        
        with open(html_file, "r", encoding="utf-8") as f:
            content = f.read()
            
        if "Open Food Facts" not in content:
            brand_issues.append(f"- **Open Food Facts** in `{html_file}`: Brand name seems to be missing or translated entirely.")
            
    return brand_issues

def check_tags_facets():
    issues = []
    for tags_file in glob.glob("po/tags/*.po"):
        with open(tags_file, "r", encoding="utf-8") as f:
            content = f.read()
        
        blocks = content.split('\n\n')
        for block in blocks:
            if "part of an url" in block:
                msgstr_match = re.search(r'msgstr\s+"([^"]+)"', block)
                if msgstr_match:
                    msgstr = msgstr_match.group(1)
                    if not msgstr: continue
                    
                    if any(c.isupper() for c in msgstr) or ' ' in msgstr:
                        locale = os.path.basename(tags_file)
                        issues.append(f"- **Invalid URL Facet** in `{tags_file}`: `{msgstr}` contains spaces or capitals. It must use hyphens and be lowercase.")
    return issues

def check_po_consistency():
    issues = []
    # Simplified consistency check logic that could be added in the future
    return issues

def main():
    print("## 🔍 Translation Validation Report")
    print("")
    print("This is an automated check of translation quality based on `AGENTS.md` guidelines.")
    print("")
    
    brand_issues, url_issues, image_issues, placeholder_issues, badge_issues = check_po_files()
    html_brand_issues = check_html_files()
    facet_issues = check_tags_facets()
    
    brand_issues.extend(html_brand_issues)
    
    total_issues = len(brand_issues) + len(url_issues) + len(image_issues) + len(placeholder_issues) + len(facet_issues) + len(badge_issues)
    
    if total_issues == 0:
        print("### ✅ No Issues Found")
        print("All translations look good!")
        sys.exit(0)
        
    if facet_issues:
        print("### ⚠️ Invalid Facet URLs")
        print(f"Found {len(facet_issues)} issues:")
        for issue in facet_issues[:50]: print(issue)
        if len(facet_issues) > 50: print(f"...and {len(facet_issues) - 50} more issues.\n")
        
    if placeholder_issues:
        print("### ⚠️ Placeholder & Syntax Parity")
        print(f"Found {len(placeholder_issues)} issues:")
        for issue in placeholder_issues[:50]: print(issue)
        if len(placeholder_issues) > 50: print(f"...and {len(placeholder_issues) - 50} more issues.\n")
        
    if brand_issues:
        print("### ⚠️ Brand Term Should Be Preserved")
        print(f"Found {len(brand_issues)} issues:")
        for issue in brand_issues[:50]: print(issue)
        if len(brand_issues) > 50: print(f"...and {len(brand_issues) - 50} more issues.\n")
        
    if url_issues:
        print("### ⚠️ URLs Should Be Localized")
        print(f"Found {len(url_issues)} issues:")
        for issue in url_issues[:50]: print(issue)
        if len(url_issues) > 50: print(f"...and {len(url_issues) - 50} more issues.\n")
        
    if image_issues:
        print("### ⚠️ Images Must Resolve")
        print(f"Found {len(image_issues)} issues:")
        for issue in image_issues[:50]: print(issue)
        if len(image_issues) > 50: print(f"...and {len(image_issues) - 50} more issues.\n")

    if badge_issues:
        print("### ⚠️ Google Play Badges Should Be Localized")
        print(f"Found {len(badge_issues)} issues:")
        for issue in badge_issues[:50]: print(issue)
        if len(badge_issues) > 50: print(f"...and {len(badge_issues) - 50} more issues.\n")
        
    sys.exit(0)

if __name__ == '__main__':
    main()
