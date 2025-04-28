Folksonomy Engine API (Our K/V - Key-Value system to extend our data model in a collaborative way)

- The Experimental Folksonomy API allows you to add and read information beyond the traditional product format to Open Food Facts, Open Products Facts, Open Pet Food Facts and Open Beauty Facts.  
- The API is documented separately at [https://api.folksonomy.openfoodfacts.org/docs](https://api.folksonomy.openfoodfacts.org/docs)
- You can see current key values at https://world.openfoodfacts.org/properties
- A reference implementation is available to logged in users on the website, and in DEV mode in the mobile app
- You can choose to implement a generic key value CRUD system, or have bespoke input and visualization interfaces, based on your usecase (for example a boolean toggle, or a date picker for introduction date… and a bespoke UI to show the value, with additional logic)
- Please be aware that there's a chance that all data added using this API could be deleted without notice, until we mark it as stable, due to unforeseen technical issues.
