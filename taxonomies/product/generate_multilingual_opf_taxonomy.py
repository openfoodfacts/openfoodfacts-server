import json
import requests
from collections import defaultdict

def generate_multilingual_taxonomy(language_urls):
    """
    Generates a multilingual product taxonomy in JSON format from a dictionary 
    of language-specific taxonomy URLs.

    Args:
        language_urls (dict): A dictionary where keys are language codes 
                              (e.g., 'en-US', 'fr-FR') and values are the URLs 
                              to the corresponding taxonomy files.

    Returns:
        str: A JSON string representing the multilingual taxonomy.
    """
    # Using defaultdict to easily build the nested dictionary
    merged_taxonomy = defaultdict(lambda: {'name': {}})

    print("Fetching and processing taxonomy files...")

    # Loop through each language and its corresponding URL
    for lang, url in language_urls.items():
        print(f"-> Processing language: {lang}")
        try:
            # Fetch the content of the .txt file
            response = requests.get(url)
            response.raise_for_status()  # This will raise an HTTPError for bad responses (4xx or 5xx)
            
            # Split the content into lines
            lines = response.text.strip().split('\n')

            # Process each line in the taxonomy file
            for line in lines:
                # Skip header comments
                if line.startswith('#'):
                    continue

                # Split the line into ID and the category path
                parts = line.split(' - ', 1)
                if len(parts) == 2:
                    category_id_str, category_path = parts
                    try:
                        # The ID is the key for our dictionary
                        category_id = int(category_id_str)
                        
                        # The last part of the path is the category name
                        category_name = category_path.split('>')[-1].strip()

                        # Add the translated name to the corresponding category ID
                        merged_taxonomy[category_id]['name'][lang] = category_name
                        
                        # Store the full path for the first language processed (optional, but good for reference)
                        if 'full_path' not in merged_taxonomy[category_id]:
                           merged_taxonomy[category_id]['full_path'] = category_path


                    except ValueError:
                        # Handle cases where the ID is not a valid number
                        print(f"   - Warning: Skipping line with invalid ID: {line}")

        except requests.exceptions.RequestException as e:
            print(f"   - Error: Could not fetch taxonomy for language '{lang}'. Reason: {e}")

    # Convert the defaultdict to a regular dict for the final JSON output
    print("Processing complete.")
    final_taxonomy = dict(sorted(merged_taxonomy.items()))
    return json.dumps(final_taxonomy, indent=4, ensure_ascii=False)

if __name__ == '__main__':
    # --- Define your language URLs here ---
    # You can add more languages by following the format 'language-code': 'url'
    language_urls = {
        'en-US': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'fr-FR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.fr-FR.txt',
        'de-DE': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.de-DE.txt',
        'es-ES': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.es-ES.txt',
        # Example: add Italian
        # 'it-IT': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.it-IT.txt',
        # 'ar-AR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'au-AU': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-GB.txt',
        'at-AT': 'http://www.google.com/basepages/producttype/taxonomy-with-ids.de-DE.txt',
        'be-FR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.fr-FR.txt',
        'be-NL': 'http://www.google.com/basepages/producttype/taxonomy-with-ids.nl-NL.txt',
        'br-BR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.pt-BR.txt',
        # 'ca-EN': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'ca-FR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.fr-FR.txt',
        # 'cl-CL': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        # 'cn-CN': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'co-CO': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.es-ES.txt',
        'cz-CZ': 'http://www.google.com/basepages/producttype/taxonomy-with-ids.cs-CZ.txt',
        'dk-DK': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.da-DK.txt',
        # 'fi-FI': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'fr-FR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.fr-FR.txt',
        'de-DE': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.de-DE.txt',
        # 'gr-GR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        # 'hk-HK': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        # 'hu-HU': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        # 'in-IN': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        # 'id-ID': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'ie-IE': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-GB.txt',
        # 'il-IL': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'it-IT': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.it-IT.txt',
        'jp-JP': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.ja-JP.txt',
        # 'my-MY': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'mx-MX': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.es-ES.txt',
        'nl-NL': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.nl-NL.txt',
        'nz-NZ': 'http://www.google.com/basepages/producttype/taxonomy-with-ids.en-AU.txt',
        'no-NO': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.no-NO.txt',
        # 'ph-PH': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'pl-PL': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.pl-PL.txt',
        'pt-BR': 'http://www.google.com/basepages/producttype/taxonomy-with-ids.pt-BR.txt',
        # 'ro-RO': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'ru-RU': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.ru-RU.txt',
        # 'sa-SA': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        # 'sg-SG': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        # 'sk-SK': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        # 'za-ZA': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'es-ES': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.es-ES.txt',
        'se-SE': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.sv-SE.txt',
        'ch-FR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.fr-CH.txt',
        'ch-DE': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.de-CH.txt',
        'ch-IT': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.it-CH.txt',
        # 'tw-TW': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        # 'th-TH': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'tr-TR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.tr-TR.txt',
        # 'ua-UA': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        # 'ae-AE': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        'gb-GB': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-GB.txt',
        # 'us-US': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US
        # 'vn-VN': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt', # contains en-US

    }

    # Generate the multilingual taxonomy
    multilingual_json = generate_multilingual_taxonomy(language_urls)

    # Save the resulting JSON to a file
    output_filename = 'google_product_taxonomy.json'
    with open(output_filename, 'w', encoding='utf-8') as f:
        f.write(multilingual_json)

    print(f"\n✅ Successfully generated '{output_filename}'")