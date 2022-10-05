# Changelog

## [1.10.0](https://github.com/openfoodfacts/openfoodfacts-server/compare/v1.9.0...v1.10.0) (2022-09-28)


### Features

* Added the logo for the Label Bee Friendly in french ([#7360](https://github.com/openfoodfacts/openfoodfacts-server/issues/7360)) ([c005b3e](https://github.com/openfoodfacts/openfoodfacts-server/commit/c005b3e60f005713aff640c7ac595bf4ffeb481e)), closes [#7231](https://github.com/openfoodfacts/openfoodfacts-server/issues/7231)
* improved parsing of origins of ingredients ([#7398](https://github.com/openfoodfacts/openfoodfacts-server/issues/7398)) ([f14ca5a](https://github.com/openfoodfacts/openfoodfacts-server/commit/f14ca5a2a80202885654e9691bd894c3af3b8c61))
* reverting changes from a specific user ([#7367](https://github.com/openfoodfacts/openfoodfacts-server/issues/7367)) ([88c2cb9](https://github.com/openfoodfacts/openfoodfacts-server/commit/88c2cb9f5c2c7805256c83f9583c026709c28a60))
* robotoff anonymous questions ([#7379](https://github.com/openfoodfacts/openfoodfacts-server/issues/7379)) ([193ee6e](https://github.com/openfoodfacts/openfoodfacts-server/commit/193ee6e4ceef723694972787fd4fa96637c40a15))


### Bug Fixes

* better removal of mongodb files ([#7393](https://github.com/openfoodfacts/openfoodfacts-server/issues/7393)) ([ffc94f2](https://github.com/openfoodfacts/openfoodfacts-server/commit/ffc94f2c61cf27c9f047043fa60607460e5f0027))
* Change the URL of the blog in the footer ([#7388](https://github.com/openfoodfacts/openfoodfacts-server/issues/7388)) ([fe1f0e6](https://github.com/openfoodfacts/openfoodfacts-server/commit/fe1f0e618840c3eb147ddf1f1a9e2bbd887dbae0))
* changes needed for Lactalis Fromages import through Agena3000 ([#7401](https://github.com/openfoodfacts/openfoodfacts-server/issues/7401)) ([2c09c66](https://github.com/openfoodfacts/openfoodfacts-server/commit/2c09c668e4e12fa33b5db9b04c3959b6089675ed))
* fix /ecoscore redirect ([#7392](https://github.com/openfoodfacts/openfoodfacts-server/issues/7392)) ([fe266f2](https://github.com/openfoodfacts/openfoodfacts-server/commit/fe266f262614e9a2a15297febf1f8619fff7f9ad))
* small changes in product files sent by Carrefour ([#7376](https://github.com/openfoodfacts/openfoodfacts-server/issues/7376)) ([7ffef9f](https://github.com/openfoodfacts/openfoodfacts-server/commit/7ffef9fcce395f763b82be7d4332fba8c8c8877f))
* sso for wiki ([#7408](https://github.com/openfoodfacts/openfoodfacts-server/issues/7408)) ([8988111](https://github.com/openfoodfacts/openfoodfacts-server/commit/89881113eded77edf9d81ef847c5c0f276ec19a1))


### Translations

* New Crowdin translations to review and merge ([#7317](https://github.com/openfoodfacts/openfoodfacts-server/issues/7317)) ([6cb9c05](https://github.com/openfoodfacts/openfoodfacts-server/commit/6cb9c050d6aab0cb053d2be52c3bfa737a34f921))


### Taxonomy

* add Polish translations, fix some typos ([#7405](https://github.com/openfoodfacts/openfoodfacts-server/issues/7405)) ([ea98a5d](https://github.com/openfoodfacts/openfoodfacts-server/commit/ea98a5daf0a17224339d1fe0ef09620a4f6421b3))
* added ingredients for Pipi and some beers in HR ([#7402](https://github.com/openfoodfacts/openfoodfacts-server/issues/7402)) ([b7e1c60](https://github.com/openfoodfacts/openfoodfacts-server/commit/b7e1c60a44e60f2aae949aee5a7e9cd5cac414af))
* Beef patties and vegan desserts ([#7358](https://github.com/openfoodfacts/openfoodfacts-server/issues/7358)) ([23f8d5a](https://github.com/openfoodfacts/openfoodfacts-server/commit/23f8d5adbf5623d017ca6983cdd8eff6a78714d6))
* fix Pork ham escalope ([#7382](https://github.com/openfoodfacts/openfoodfacts-server/issues/7382)) ([8f3e434](https://github.com/openfoodfacts/openfoodfacts-server/commit/8f3e4346d5574021e1af04a4fa5daf7acef9c4e0))
* fix some unit test errors ([#7397](https://github.com/openfoodfacts/openfoodfacts-server/issues/7397)) ([250e17b](https://github.com/openfoodfacts/openfoodfacts-server/commit/250e17bf7e7b89ba82ea8363ebb90027a83df954))
* rypsiöljy ingredient ([#7396](https://github.com/openfoodfacts/openfoodfacts-server/issues/7396)) ([b4bf8df](https://github.com/openfoodfacts/openfoodfacts-server/commit/b4bf8dfcfa514f540988bf112385751b4adcd1f7))
* use Cooked Peppers as proxy for Frozen Peppers ([#7395](https://github.com/openfoodfacts/openfoodfacts-server/issues/7395)) ([a29d20a](https://github.com/openfoodfacts/openfoodfacts-server/commit/a29d20aefaaa9c8e87ba52bec49bb1c0cc2f3ac7))

## [1.9.0](https://github.com/openfoodfacts/openfoodfacts-server/compare/v1.8.0...v1.9.0) (2022-09-20)


### Features

* Add taxonomy entries for quality ([#7189](https://github.com/openfoodfacts/openfoodfacts-server/issues/7189)) ([8f9caf9](https://github.com/openfoodfacts/openfoodfacts-server/commit/8f9caf98a2a43d2928295fdb97ed746effb91a57))
* Documentation spelling policy ([#7142](https://github.com/openfoodfacts/openfoodfacts-server/issues/7142)) ([9a666ac](https://github.com/openfoodfacts/openfoodfacts-server/commit/9a666ac16468335eb0214b6445599840cf2cae78))
* send events when editing products ([#7303](https://github.com/openfoodfacts/openfoodfacts-server/issues/7303)) ([8ef9eea](https://github.com/openfoodfacts/openfoodfacts-server/commit/8ef9eea2c836605ce97e424520506ed006fa3233))


### Bug Fixes

* broken CSV ([#2426](https://github.com/openfoodfacts/openfoodfacts-server/issues/2426)) ([#7318](https://github.com/openfoodfacts/openfoodfacts-server/issues/7318)) ([4c62929](https://github.com/openfoodfacts/openfoodfacts-server/commit/4c629297b0d068cd741ecec75d5785b465689790))
* bug introduced by previous refactor ([476bad1](https://github.com/openfoodfacts/openfoodfacts-server/commit/476bad1cfc3486e2ef62d212e523fa34f25112d8))
* bug introduced by previous refactor ([#7214](https://github.com/openfoodfacts/openfoodfacts-server/issues/7214)) ([476bad1](https://github.com/openfoodfacts/openfoodfacts-server/commit/476bad1cfc3486e2ef62d212e523fa34f25112d8)), closes [#7201](https://github.com/openfoodfacts/openfoodfacts-server/issues/7201)
* correct order of parameters for extract_text_from_image ([#7375](https://github.com/openfoodfacts/openfoodfacts-server/issues/7375)) ([0a53b47](https://github.com/openfoodfacts/openfoodfacts-server/commit/0a53b4795bd8cb271fa375f85c046a65caee40f4))
* Fix typos in the Folksonomy JS code ([#7147](https://github.com/openfoodfacts/openfoodfacts-server/issues/7147)) ([896d6c9](https://github.com/openfoodfacts/openfoodfacts-server/commit/896d6c9fe957ce7e74fa4371b6138accac53a8e0))
* ingredient parents ([#7364](https://github.com/openfoodfacts/openfoodfacts-server/issues/7364)) ([0db5a8b](https://github.com/openfoodfacts/openfoodfacts-server/commit/0db5a8becbeae8c9b8784fc6b3848979aed24bb8))
* minor repairs in the categories taxonomy ([#7371](https://github.com/openfoodfacts/openfoodfacts-server/issues/7371)) ([bf778b4](https://github.com/openfoodfacts/openfoodfacts-server/commit/bf778b4feb8e4b5f440a5e36eb7b79253c1f34cf))
* mongodb _id must be a string ([#7255](https://github.com/openfoodfacts/openfoodfacts-server/issues/7255)) ([1b14745](https://github.com/openfoodfacts/openfoodfacts-server/commit/1b14745373aa738123994f1cb74cf80e527c3292))
* pb with initial slash in query string of redirects  ([#7164](https://github.com/openfoodfacts/openfoodfacts-server/issues/7164)) ([8902cb4](https://github.com/openfoodfacts/openfoodfacts-server/commit/8902cb405faa0e2b5045f58c8c08ca3c346d6add))
* prevent default mod_perl error message to be appended ([#7331](https://github.com/openfoodfacts/openfoodfacts-server/issues/7331)) ([978fe5d](https://github.com/openfoodfacts/openfoodfacts-server/commit/978fe5de246708a035a82bccd8c1f0d41c97332a))
* put back symlinks for cgi/product.pl ([#7302](https://github.com/openfoodfacts/openfoodfacts-server/issues/7302)) ([c49176e](https://github.com/openfoodfacts/openfoodfacts-server/commit/c49176e68f57327d8ab790421eb8e69182d1bcd2))
* send set-cookie headers in redirects ([#7258](https://github.com/openfoodfacts/openfoodfacts-server/issues/7258)) ([202070c](https://github.com/openfoodfacts/openfoodfacts-server/commit/202070c8a315060074d736e2283fb904c44a5a8e))
* set cookie when redirecting ([#7149](https://github.com/openfoodfacts/openfoodfacts-server/issues/7149)) ([b297ed8](https://github.com/openfoodfacts/openfoodfacts-server/commit/b297ed858d526332649562cdec5f1d36be184984))
* Social media link preview shows old logo Fixes [#7059](https://github.com/openfoodfacts/openfoodfacts-server/issues/7059) ([#7177](https://github.com/openfoodfacts/openfoodfacts-server/issues/7177)) ([6eaa392](https://github.com/openfoodfacts/openfoodfacts-server/commit/6eaa392d197f3f529f2b4985cc4c1645b41a0b6b))


### Translations

* New Crowdin translations to review and merge ([#7152](https://github.com/openfoodfacts/openfoodfacts-server/issues/7152)) ([4b1f2e4](https://github.com/openfoodfacts/openfoodfacts-server/commit/4b1f2e4dffb9d065ce148754439d3c4d188278d1))
* New Crowdin translations to review and merge ([#7156](https://github.com/openfoodfacts/openfoodfacts-server/issues/7156)) ([5f2f2dc](https://github.com/openfoodfacts/openfoodfacts-server/commit/5f2f2dc0c64848e8fe8352bbdadf2ea1a272f37f))
* New Crowdin translations to review and merge ([#7158](https://github.com/openfoodfacts/openfoodfacts-server/issues/7158)) ([955bb2e](https://github.com/openfoodfacts/openfoodfacts-server/commit/955bb2e00325597f14992e5917afc73f9d81ebc4))
* New Crowdin translations to review and merge ([#7292](https://github.com/openfoodfacts/openfoodfacts-server/issues/7292)) ([08c46d6](https://github.com/openfoodfacts/openfoodfacts-server/commit/08c46d6600a0ef4bc98ddb464577d7ea19105db8))
* New Crowdin translations to review and merge ([#7293](https://github.com/openfoodfacts/openfoodfacts-server/issues/7293)) ([ae3b75d](https://github.com/openfoodfacts/openfoodfacts-server/commit/ae3b75dbf0410ccb2b4a9ce5d252027ac690712a))
* New Crowdin translations to review and merge ([#7300](https://github.com/openfoodfacts/openfoodfacts-server/issues/7300)) ([ae83d7f](https://github.com/openfoodfacts/openfoodfacts-server/commit/ae83d7f076e1228058963583579a178d7057d601))


### Taxonomy

* add breading and whole grain flour blend ([#7185](https://github.com/openfoodfacts/openfoodfacts-server/issues/7185)) ([b373458](https://github.com/openfoodfacts/openfoodfacts-server/commit/b37345898dffe1fe085ffdacf5f92fcc2b8c7b13))
* add missing polish translations ([#7346](https://github.com/openfoodfacts/openfoodfacts-server/issues/7346)) ([108b5cc](https://github.com/openfoodfacts/openfoodfacts-server/commit/108b5cc4478a648e098de450e17530026376866f))
* Add new packaging materials and translations ([#7198](https://github.com/openfoodfacts/openfoodfacts-server/issues/7198)) ([589fcd2](https://github.com/openfoodfacts/openfoodfacts-server/commit/589fcd2f9384114fffb833805c9fa2d4ff3eaff2))
* added croatian translation for raw cashews ([#7227](https://github.com/openfoodfacts/openfoodfacts-server/issues/7227)) ([9fb90de](https://github.com/openfoodfacts/openfoodfacts-server/commit/9fb90de7cd5e10349cc3f7cb4dddecb23ea2ec9f))
* added pasteurised milk in HR ([#7322](https://github.com/openfoodfacts/openfoodfacts-server/issues/7322)) ([3a8055b](https://github.com/openfoodfacts/openfoodfacts-server/commit/3a8055b235578d65942f2eee46dfaf5879dc5ff7))
* added some ingredients for cremolli hazelnut - belprom in HR ([#7328](https://github.com/openfoodfacts/openfoodfacts-server/issues/7328)) ([850a0c0](https://github.com/openfoodfacts/openfoodfacts-server/commit/850a0c08bdd34bb4d1e5523fc098b6b074b2e8ab))
* added some ingredients for crunchy almonds - spar in HR ([#7332](https://github.com/openfoodfacts/openfoodfacts-server/issues/7332)) ([d7b8583](https://github.com/openfoodfacts/openfoodfacts-server/commit/d7b85834a13d045160410cdde15a00a465923dd4))
* added some ingredients for madarica from pan-pek in HR ([#7337](https://github.com/openfoodfacts/openfoodfacts-server/issues/7337)) ([c48f742](https://github.com/openfoodfacts/openfoodfacts-server/commit/c48f742c157b8eb4415fbc8adbac32e581048c7c))
* added some ingredients for margarin kolace i kuhanje in HR ([#7348](https://github.com/openfoodfacts/openfoodfacts-server/issues/7348)) ([5743b96](https://github.com/openfoodfacts/openfoodfacts-server/commit/5743b96fee5fa4afcae8be33d2461de8dc5aea5e))
* added some ingredients for sir s paprom from gligora in HR ([#7347](https://github.com/openfoodfacts/openfoodfacts-server/issues/7347)) ([11bc581](https://github.com/openfoodfacts/openfoodfacts-server/commit/11bc581301e23c188dd28522a12f26946a894a03))
* added some ingredients for toast tojeto in HR ([#7325](https://github.com/openfoodfacts/openfoodfacts-server/issues/7325)) ([c4b8302](https://github.com/openfoodfacts/openfoodfacts-server/commit/c4b830281afb833a21b3ab3548b2f5ee7441a08b))
* added some ingredients of krem kakao tojeto in HR ([#7324](https://github.com/openfoodfacts/openfoodfacts-server/issues/7324)) ([066f075](https://github.com/openfoodfacts/openfoodfacts-server/commit/066f0750a93600ec3889f8315a4e7dbbdcd97c4e))
* added some ingredients of monster energy drink in HR ([#7323](https://github.com/openfoodfacts/openfoodfacts-server/issues/7323)) ([fec670a](https://github.com/openfoodfacts/openfoodfacts-server/commit/fec670a62c6407ea77a75fdb775c8d714ffb0d73))
* added varietal for croatians wines ([#7370](https://github.com/openfoodfacts/openfoodfacts-server/issues/7370)) ([b7965f2](https://github.com/openfoodfacts/openfoodfacts-server/commit/b7965f26f6fcca52bffe69bae21b334b7e7c88b1))
* adding croatian translation for ingredient of choco delicia ([#7299](https://github.com/openfoodfacts/openfoodfacts-server/issues/7299)) ([1e1e092](https://github.com/openfoodfacts/openfoodfacts-server/commit/1e1e092f0a480961622e37d12f4a74bb4e817ae9))
* Adding Dutch translations ([#7264](https://github.com/openfoodfacts/openfoodfacts-server/issues/7264)) ([a9748ed](https://github.com/openfoodfacts/openfoodfacts-server/commit/a9748eda62028c5b1059ece3057b984a5f5d9ee0))
* Adding Dutch translations for taxonomies ([#7268](https://github.com/openfoodfacts/openfoodfacts-server/issues/7268)) ([36854ad](https://github.com/openfoodfacts/openfoodfacts-server/commit/36854adbdcc45603b570d5799aca7b69e237b875))
* additives classes - syn ro regulatori de aciditate ([#7229](https://github.com/openfoodfacts/openfoodfacts-server/issues/7229)) ([8eb3959](https://github.com/openfoodfacts/openfoodfacts-server/commit/8eb3959bff69c2af0a9c10ca952aa516dd0fec07))
* Bulgarian additions ([#7190](https://github.com/openfoodfacts/openfoodfacts-server/issues/7190)) ([a04fa17](https://github.com/openfoodfacts/openfoodfacts-server/commit/a04fa171e9f5a8e9a718d85bc7f301f58895b628))
* Bulgarian additions ([#7297](https://github.com/openfoodfacts/openfoodfacts-server/issues/7297)) ([3ee511c](https://github.com/openfoodfacts/openfoodfacts-server/commit/3ee511c63d4b7c9a7d38247f14f18cc3ece92ac0))
* categories - Tartinades d'oeufs ([#7223](https://github.com/openfoodfacts/openfoodfacts-server/issues/7223)) ([e37c5e2](https://github.com/openfoodfacts/openfoodfacts-server/commit/e37c5e2fb47756d9b513089a8efe5fbbdd5bd917))
* Cheeses to grill ([#7159](https://github.com/openfoodfacts/openfoodfacts-server/issues/7159)) ([361a10c](https://github.com/openfoodfacts/openfoodfacts-server/commit/361a10cfffeded751612406ba7c21d5cf52f49e1))
* Create generic categ Poulardes ([#7341](https://github.com/openfoodfacts/openfoodfacts-server/issues/7341)) ([91193b2](https://github.com/openfoodfacts/openfoodfacts-server/commit/91193b2a0dd8fe93757ff08e61cfb5ad3ae3e202))
* create Pâtisson (squash) ([#7344](https://github.com/openfoodfacts/openfoodfacts-server/issues/7344)) ([2e7f30a](https://github.com/openfoodfacts/openfoodfacts-server/commit/2e7f30a75660419fbb9c50b48e98ddc241037b30))
* cukier kokosowy ([#7165](https://github.com/openfoodfacts/openfoodfacts-server/issues/7165)) ([3d4983a](https://github.com/openfoodfacts/openfoodfacts-server/commit/3d4983a7665664e3938e55bd32fa331f855e02bc))
* de:Koagulationsmittel ([#7167](https://github.com/openfoodfacts/openfoodfacts-server/issues/7167)) ([32cc68a](https://github.com/openfoodfacts/openfoodfacts-server/commit/32cc68a6f4a2fde8ce90b583265a264841d60bc1))
* Fermented dairy desserts ([#7172](https://github.com/openfoodfacts/openfoodfacts-server/issues/7172)) ([6d7e8c8](https://github.com/openfoodfacts/openfoodfacts-server/commit/6d7e8c8da391e459500d4ed5dadfc3f108b12e69))
* fi ingredients ([#7326](https://github.com/openfoodfacts/openfoodfacts-server/issues/7326)) ([69ff202](https://github.com/openfoodfacts/openfoodfacts-server/commit/69ff2020c258fe8831c6f03b7a6e9455ac489523))
* Ingredient additions ([#7245](https://github.com/openfoodfacts/openfoodfacts-server/issues/7245)) ([6445162](https://github.com/openfoodfacts/openfoodfacts-server/commit/6445162c63f4b0b377307423c1f0478164fe6a24))
* ingredients - Pumpkin seeds ([#7228](https://github.com/openfoodfacts/openfoodfacts-server/issues/7228)) ([bfd7ba4](https://github.com/openfoodfacts/openfoodfacts-server/commit/bfd7ba4c894a8e7da49caf6f856610f46691819b))
* isosport and some old added product hr ([#7363](https://github.com/openfoodfacts/openfoodfacts-server/issues/7363)) ([78edefd](https://github.com/openfoodfacts/openfoodfacts-server/commit/78edefd55a031e35b753fae74907cfdcacc4dd8e))
* minerals - syn nl - ijzer(II)fumaraat ([#7143](https://github.com/openfoodfacts/openfoodfacts-server/issues/7143)) ([26526ad](https://github.com/openfoodfacts/openfoodfacts-server/commit/26526ad6068df06b2cce99bf4ee07763e3096721))
* Mueslis ([#7221](https://github.com/openfoodfacts/openfoodfacts-server/issues/7221)) ([ad34494](https://github.com/openfoodfacts/openfoodfacts-server/commit/ad3449470eef555bd17951d322e4e866c214564c))
* Remove repeated entries ([#7200](https://github.com/openfoodfacts/openfoodfacts-server/issues/7200)) ([14a920e](https://github.com/openfoodfacts/openfoodfacts-server/commit/14a920e868e2d45dabd5ef618bb8636214759637))
* ro ingredients ([#7342](https://github.com/openfoodfacts/openfoodfacts-server/issues/7342)) ([8b822d2](https://github.com/openfoodfacts/openfoodfacts-server/commit/8b822d22e1a7cb884279c4a8e81df46bd8bbece8))
* Serek homogenizowany ([#7237](https://github.com/openfoodfacts/openfoodfacts-server/issues/7237)) ([3f1d286](https://github.com/openfoodfacts/openfoodfacts-server/commit/3f1d2863a67197cd55e70b2934ec7074ca17f23e))

## [1.8.0](https://github.com/openfoodfacts/openfoodfacts-server/compare/v1.7.0...v1.8.0) (2022-07-27)


### Features

* Cascading elsif limit 13 ([#7130](https://github.com/openfoodfacts/openfoodfacts-server/issues/7130)) ([c8274e0](https://github.com/openfoodfacts/openfoodfacts-server/commit/c8274e0e8d8f84233203e28ef8512d187e32974c))
* Deep nest limit 12 ([#7124](https://github.com/openfoodfacts/openfoodfacts-server/issues/7124)) ([3607b5d](https://github.com/openfoodfacts/openfoodfacts-server/commit/3607b5d5ba13a3501ef2b28efdfef876fd95bf20))
* Nutrient levels knowledge panels with facts and recommendations ([#6980](https://github.com/openfoodfacts/openfoodfacts-server/issues/6980)) ([80911fa](https://github.com/openfoodfacts/openfoodfacts-server/commit/80911fa568de12bd07c82c27bf180ea72f92586d))
* parse origins of ingredients field ([#6995](https://github.com/openfoodfacts/openfoodfacts-server/issues/6995)) ([79fa9ae](https://github.com/openfoodfacts/openfoodfacts-server/commit/79fa9ae46a45bef89026c87375a63de401f2b3b3))
* uncommenting severity 4 rules in .perlcriticrc ([7599272](https://github.com/openfoodfacts/openfoodfacts-server/commit/75992723086c5a1ae08c142cc8b366a10f4bd803))
* uncommenting severity 4 rules in `.perlcriticrc` ([#7109](https://github.com/openfoodfacts/openfoodfacts-server/issues/7109)) ([7599272](https://github.com/openfoodfacts/openfoodfacts-server/commit/75992723086c5a1ae08c142cc8b366a10f4bd803))


### Bug Fixes

* `Ingredients.pm` reused variables ([#7115](https://github.com/openfoodfacts/openfoodfacts-server/issues/7115)) ([4a391f0](https://github.com/openfoodfacts/openfoodfacts-server/commit/4a391f058da9335c1b768f8ae137a727e5807cc5))
* activate the producers platform with PRODUCER_PLATFORM env variable ([#7135](https://github.com/openfoodfacts/openfoodfacts-server/issues/7135)) ([783d625](https://github.com/openfoodfacts/openfoodfacts-server/commit/783d625d7252b18c493207d90094980e071ef6b2))
* add missing subdomain to redirect url [#6993](https://github.com/openfoodfacts/openfoodfacts-server/issues/6993) ([#7019](https://github.com/openfoodfacts/openfoodfacts-server/issues/7019)) ([7b1029b](https://github.com/openfoodfacts/openfoodfacts-server/commit/7b1029bf28ddeb54f4a5cead70b48bcf8badfbb9))
* better wording for adding a precise category ([#7038](https://github.com/openfoodfacts/openfoodfacts-server/issues/7038)) ([42398be](https://github.com/openfoodfacts/openfoodfacts-server/commit/42398bef9879a6cecc34595f9267b7dc3cca20b4))
* columns synonyms for Packtic import ([#7099](https://github.com/openfoodfacts/openfoodfacts-server/issues/7099)) ([30cc195](https://github.com/openfoodfacts/openfoodfacts-server/commit/30cc1952502e5eae4a95e4552a4745d410c2dbc0))
* countries.pl for countries dropdown ([#7138](https://github.com/openfoodfacts/openfoodfacts-server/issues/7138)) ([77eb795](https://github.com/openfoodfacts/openfoodfacts-server/commit/77eb795e6d37b37f04c2717c09dfd2c281ec4b45))
* explicit return statements in `Attributes.pm` ([#7086](https://github.com/openfoodfacts/openfoodfacts-server/issues/7086)) ([59a8280](https://github.com/openfoodfacts/openfoodfacts-server/commit/59a82809f9251036cc61279913b073aa513f4f19))
* explicit return statements in `Ecoscore.pm` ([#7089](https://github.com/openfoodfacts/openfoodfacts-server/issues/7089)) ([9224de3](https://github.com/openfoodfacts/openfoodfacts-server/commit/9224de3cce26d52d256355841b5722f290396600))
* explicit return statements in `GS1.pm` ([#7083](https://github.com/openfoodfacts/openfoodfacts-server/issues/7083)) ([fcb4d8e](https://github.com/openfoodfacts/openfoodfacts-server/commit/fcb4d8ef2bd6d3e0d8b44ecc1ce2aeab49230146))
* explicit return statements in `Ingredients.pm` ([#7097](https://github.com/openfoodfacts/openfoodfacts-server/issues/7097)) ([8b66f13](https://github.com/openfoodfacts/openfoodfacts-server/commit/8b66f13d85ae1a3563070666dd47842bcd0aea94))
* explicit return statements in `KnowledgePanels.pm` ([#7082](https://github.com/openfoodfacts/openfoodfacts-server/issues/7082)) ([c1c901e](https://github.com/openfoodfacts/openfoodfacts-server/commit/c1c901ed421bd53f7fce45721a7b9f712fd5c283))
* explicit return statements in Attributes.pm ([59a8280](https://github.com/openfoodfacts/openfoodfacts-server/commit/59a82809f9251036cc61279913b073aa513f4f19))
* explicit return statements in GS1.pm ([fcb4d8e](https://github.com/openfoodfacts/openfoodfacts-server/commit/fcb4d8ef2bd6d3e0d8b44ecc1ce2aeab49230146))
* export PRODUCERS_PLATFORM=1 for producers platform in docker ([783d625](https://github.com/openfoodfacts/openfoodfacts-server/commit/783d625d7252b18c493207d90094980e071ef6b2))
* finish cookie / init_request refactor ([#7126](https://github.com/openfoodfacts/openfoodfacts-server/issues/7126)) ([8a3ee59](https://github.com/openfoodfacts/openfoodfacts-server/commit/8a3ee5940cf343b6328399aba70f4f0ff0650353))
* fix the old usage example in makefile ([61cef28](https://github.com/openfoodfacts/openfoodfacts-server/commit/61cef28df3908ce2a52bb82de9dc6cf1b3ebd5b7))
* fix the old usage example in makefile ([#7121](https://github.com/openfoodfacts/openfoodfacts-server/issues/7121)) ([61cef28](https://github.com/openfoodfacts/openfoodfacts-server/commit/61cef28df3908ce2a52bb82de9dc6cf1b3ebd5b7))
* fix vitamin b1 thiamin %DV  ([#7072](https://github.com/openfoodfacts/openfoodfacts-server/issues/7072)) ([4699f67](https://github.com/openfoodfacts/openfoodfacts-server/commit/4699f674b5a0bbe8162b61ce1cef109d6490ba73))
* fix vitamin b1 thiamin %DV [#6882](https://github.com/openfoodfacts/openfoodfacts-server/issues/6882) ([4699f67](https://github.com/openfoodfacts/openfoodfacts-server/commit/4699f674b5a0bbe8162b61ce1cef109d6490ba73))
* fixes redirects ([#7136](https://github.com/openfoodfacts/openfoodfacts-server/issues/7136)) ([ad78f9e](https://github.com/openfoodfacts/openfoodfacts-server/commit/ad78f9e7955ec0aa5374ed1683368d781251514e))
* Initialization of state variables in list context currently forbidden ([44b9fc1](https://github.com/openfoodfacts/openfoodfacts-server/commit/44b9fc1f4067fe40c3bacb8d6dc8ce733045a892))
* Initialization of state variables in list context currently forbidden (perl version < 5.28) ([#7058](https://github.com/openfoodfacts/openfoodfacts-server/issues/7058)) ([44b9fc1](https://github.com/openfoodfacts/openfoodfacts-server/commit/44b9fc1f4067fe40c3bacb8d6dc8ce733045a892))
* Made changes in the readme file ([#4859](https://github.com/openfoodfacts/openfoodfacts-server/issues/4859)) ([fcb8727](https://github.com/openfoodfacts/openfoodfacts-server/commit/fcb87279887f996853842e5244de0b06b5277191))
* return statements ([#7104](https://github.com/openfoodfacts/openfoodfacts-server/issues/7104)) ([6751d3e](https://github.com/openfoodfacts/openfoodfacts-server/commit/6751d3e8f87bbf30b8578c19885c33108a031ea2))
* return statements to KnowledgePanels.pm ([c1c901e](https://github.com/openfoodfacts/openfoodfacts-server/commit/c1c901ed421bd53f7fce45721a7b9f712fd5c283))
* set access-control-allow-credentials=true in auth.pl  ([#7022](https://github.com/openfoodfacts/openfoodfacts-server/issues/7022)) ([423df0f](https://github.com/openfoodfacts/openfoodfacts-server/commit/423df0f8d3cc291fb09dd842415289f2df1d55e1))
* spelling correction ([#7141](https://github.com/openfoodfacts/openfoodfacts-server/issues/7141)) ([af59dc1](https://github.com/openfoodfacts/openfoodfacts-server/commit/af59dc1155a096328e9dc4710985a12a8be878c3))
* uninitialized value ([#6997](https://github.com/openfoodfacts/openfoodfacts-server/issues/6997)) ([28bcc4d](https://github.com/openfoodfacts/openfoodfacts-server/commit/28bcc4dc0fecf4d55f16198e0ebc5ae602bc80ca))
* use normalized ids for untaxonomized ingredients and specific ingredients ([#7131](https://github.com/openfoodfacts/openfoodfacts-server/issues/7131)) ([d57cd90](https://github.com/openfoodfacts/openfoodfacts-server/commit/d57cd907c9aeaa2649abb54217d40512ec81633d))


### Taxonomy

* "Nature & Progrès" is not biodynamic ([#7081](https://github.com/openfoodfacts/openfoodfacts-server/issues/7081)) ([d86f465](https://github.com/openfoodfacts/openfoodfacts-server/commit/d86f465ab3130ac6d4c0b1de4333017603b2bde5))
* add new Polish translations ([#7068](https://github.com/openfoodfacts/openfoodfacts-server/issues/7068)) ([3f0db87](https://github.com/openfoodfacts/openfoodfacts-server/commit/3f0db8778506cd0a55d97b3fcaeab379e79d94ff))
* add new polish translations for ingredients ([#7119](https://github.com/openfoodfacts/openfoodfacts-server/issues/7119)) ([0e98b74](https://github.com/openfoodfacts/openfoodfacts-server/commit/0e98b7463f0e1e42dc6171da10e8176ab901cb6b))
* add polish name of UHT pasteurised milk to ingridients.txt ([#6976](https://github.com/openfoodfacts/openfoodfacts-server/issues/6976)) ([64e2a81](https://github.com/openfoodfacts/openfoodfacts-server/commit/64e2a81bef1d7ce7eb980c4b48bde436b9a1688e))
* BG Additions ([#6982](https://github.com/openfoodfacts/openfoodfacts-server/issues/6982)) ([b257ffe](https://github.com/openfoodfacts/openfoodfacts-server/commit/b257ffed5cda5fca1b697bb1796f02d696d75258))
* Certified B Corporation, without pesticides ([#7077](https://github.com/openfoodfacts/openfoodfacts-server/issues/7077)) ([1d2aabb](https://github.com/openfoodfacts/openfoodfacts-server/commit/1d2aabba500b0c0c870f4c568591efbbc88e2515))
* Changed some entries, mostly double entries ([#7049](https://github.com/openfoodfacts/openfoodfacts-server/issues/7049)) ([fdaac75](https://github.com/openfoodfacts/openfoodfacts-server/commit/fdaac75234717de5c4fd3d9165583a2f7100b4d2))
* Corrections to cheeses ([#7065](https://github.com/openfoodfacts/openfoodfacts-server/issues/7065)) ([67c3c74](https://github.com/openfoodfacts/openfoodfacts-server/commit/67c3c74d6de6496fd967da7b30b8d2eb25d9db54))
* de:braune Linsen ([#7080](https://github.com/openfoodfacts/openfoodfacts-server/issues/7080)) ([26b6d41](https://github.com/openfoodfacts/openfoodfacts-server/commit/26b6d4157db53913d1ebab4539979c24c781b693))
* Finnish products ([#6950](https://github.com/openfoodfacts/openfoodfacts-server/issues/6950)) ([efa31c7](https://github.com/openfoodfacts/openfoodfacts-server/commit/efa31c7e447153048471e13d924660e771b549e6))
* Fixed paprika issue ([#7035](https://github.com/openfoodfacts/openfoodfacts-server/issues/7035)) ([2227200](https://github.com/openfoodfacts/openfoodfacts-server/commit/2227200a90d6a49749a59e240ac55dde556796fa))
* flaxseed fiber ([#6945](https://github.com/openfoodfacts/openfoodfacts-server/issues/6945)) ([075be82](https://github.com/openfoodfacts/openfoodfacts-server/commit/075be82f760c4155eea8ebe4061c136dd9c6642c))
* German synonyms ([#7098](https://github.com/openfoodfacts/openfoodfacts-server/issues/7098)) ([e1925ed](https://github.com/openfoodfacts/openfoodfacts-server/commit/e1925ed19dada40c4416c65df32c24ccf45d8f41))
* Meat patties ([#7002](https://github.com/openfoodfacts/openfoodfacts-server/issues/7002)) ([e1f1c3b](https://github.com/openfoodfacts/openfoodfacts-server/commit/e1f1c3b13c9283a5293b31e8585d3fda0da203ef))
* Polish translations of ingredient processing ([#7029](https://github.com/openfoodfacts/openfoodfacts-server/issues/7029)) ([fb53651](https://github.com/openfoodfacts/openfoodfacts-server/commit/fb536516a9c63a8a74c5d07fdf52627e6ceb47e7))
* Synonyms for cs ([#6979](https://github.com/openfoodfacts/openfoodfacts-server/issues/6979)) ([b7344d6](https://github.com/openfoodfacts/openfoodfacts-server/commit/b7344d676af427c025319a204db1433502966878))


### Translations

* New Crowdin translations to review and merge ([#6975](https://github.com/openfoodfacts/openfoodfacts-server/issues/6975)) ([2c726f2](https://github.com/openfoodfacts/openfoodfacts-server/commit/2c726f2626512201ba8e4ca4313cda7924ff08db))
* New Crowdin translations to review and merge ([#7046](https://github.com/openfoodfacts/openfoodfacts-server/issues/7046)) ([28d9ae6](https://github.com/openfoodfacts/openfoodfacts-server/commit/28d9ae6b24e55f03a8ddc33015973661a2a4a9ce))
* New Crowdin translations to review and merge ([#7084](https://github.com/openfoodfacts/openfoodfacts-server/issues/7084)) ([331dbb9](https://github.com/openfoodfacts/openfoodfacts-server/commit/331dbb9539da86e63d5d093fb089e67a850c7f8d))

## [1.7.0](https://github.com/openfoodfacts/openfoodfacts-server/compare/v1.6.0...v1.7.0) (2022-06-27)


### Features

* "edible" should be recognized as a stop word ([#6940](https://github.com/openfoodfacts/openfoodfacts-server/issues/6940)) ([7082172](https://github.com/openfoodfacts/openfoodfacts-server/commit/7082172154d634aa4e8dac3133703f199ed1e6e9))
* add actions to panels [#6902](https://github.com/openfoodfacts/openfoodfacts-server/issues/6902) ([#6903](https://github.com/openfoodfacts/openfoodfacts-server/issues/6903)) ([e03e2e1](https://github.com/openfoodfacts/openfoodfacts-server/commit/e03e2e196fd27d5f18cabcb1ad073c7a3400d8c3))
* add new Open Food Facts logos ([#6901](https://github.com/openfoodfacts/openfoodfacts-server/issues/6901)) ([3d2ec49](https://github.com/openfoodfacts/openfoodfacts-server/commit/3d2ec4930704048f50b645bd23548758d8a9c28b))
* deactivate physical activities equivalence panel ([#6943](https://github.com/openfoodfacts/openfoodfacts-server/issues/6943)) ([855b127](https://github.com/openfoodfacts/openfoodfacts-server/commit/855b127349fc8fae82482a53495a33191af2fc38))
* extend ingredients analysis panels with details and call for help ([#6905](https://github.com/openfoodfacts/openfoodfacts-server/issues/6905)) ([8690daf](https://github.com/openfoodfacts/openfoodfacts-server/commit/8690dafcc67b671a4b5ac3f3fc08a6e212efc88c))
* Support for unit name normalization ([#6878](https://github.com/openfoodfacts/openfoodfacts-server/issues/6878)) ([b1bc521](https://github.com/openfoodfacts/openfoodfacts-server/commit/b1bc5210fea2d7c054e6949895b0909bfe192185))


### Bug Fixes

* "refined wheat flour" and "maida" should be recognized as a type of flour ([#6939](https://github.com/openfoodfacts/openfoodfacts-server/issues/6939)) ([0559775](https://github.com/openfoodfacts/openfoodfacts-server/commit/0559775ad31e797604b3cdb082fb9d3ee0ae9ef6))
* $request_ref->{count} not used ([#6914](https://github.com/openfoodfacts/openfoodfacts-server/issues/6914)) ([3c12065](https://github.com/openfoodfacts/openfoodfacts-server/commit/3c12065f05a8b96f487db7ce135aaf8d62ea04d4))
* add test for cream cheese ([24f52cb](https://github.com/openfoodfacts/openfoodfacts-server/commit/24f52cb70e253e94f91e72cb8a3c5437ffdde30b))
* cream cheese is under cheeses ([24f52cb](https://github.com/openfoodfacts/openfoodfacts-server/commit/24f52cb70e253e94f91e72cb8a3c5437ffdde30b))
* display_structured_response syntax ([#6948](https://github.com/openfoodfacts/openfoodfacts-server/issues/6948)) ([525ad83](https://github.com/openfoodfacts/openfoodfacts-server/commit/525ad833604071f0a66c9b478763118b67253a95))
* duplicate `sub product_url($)` in Products.pm ([#6949](https://github.com/openfoodfacts/openfoodfacts-server/issues/6949)) ([668454e](https://github.com/openfoodfacts/openfoodfacts-server/commit/668454ef31388bca10dffda4ace679aa161936c7))
* Invalid conversion ([#6890](https://github.com/openfoodfacts/openfoodfacts-server/issues/6890)) ([dc74c0d](https://github.com/openfoodfacts/openfoodfacts-server/commit/dc74c0d61003a48cb19925326e324d4d4348e9bf))
* invalid json ([#6934](https://github.com/openfoodfacts/openfoodfacts-server/issues/6934)) ([26ca8f8](https://github.com/openfoodfacts/openfoodfacts-server/commit/26ca8f8dd27697432ae83d011ebfc9b95c281697))
* release please workflow missing a quote ([#6906](https://github.com/openfoodfacts/openfoodfacts-server/issues/6906)) ([77125d0](https://github.com/openfoodfacts/openfoodfacts-server/commit/77125d07b79356c8fc3307e56ec4083786818322))
* release please workflow pt.2 ([#6910](https://github.com/openfoodfacts/openfoodfacts-server/issues/6910)) ([9fe8d64](https://github.com/openfoodfacts/openfoodfacts-server/commit/9fe8d643b6888130c000b0b3ea1848d27b91e3e9))
* removed the `display_top_block()` sub ([6d2d1ba](https://github.com/openfoodfacts/openfoodfacts-server/commit/6d2d1ba74ec8e475b9094b6204f62030d08d516b))
* support for some common and popular US dairy ingredients ([#6955](https://github.com/openfoodfacts/openfoodfacts-server/issues/6955)) ([24f52cb](https://github.com/openfoodfacts/openfoodfacts-server/commit/24f52cb70e253e94f91e72cb8a3c5437ffdde30b))
* syntax on display_icon ([#6935](https://github.com/openfoodfacts/openfoodfacts-server/issues/6935)) ([c919b18](https://github.com/openfoodfacts/openfoodfacts-server/commit/c919b18ca004f82bad45c277519a32b3799568c0))
* typo in %DV and IU units property names  ([#6944](https://github.com/openfoodfacts/openfoodfacts-server/issues/6944)) ([dc95de9](https://github.com/openfoodfacts/openfoodfacts-server/commit/dc95de9c13f33e0b3c41052dd7d28bffc12195e9))
* typo in %DV and IU units property names [#6942](https://github.com/openfoodfacts/openfoodfacts-server/issues/6942) ([dc95de9](https://github.com/openfoodfacts/openfoodfacts-server/commit/dc95de9c13f33e0b3c41052dd7d28bffc12195e9))
* typo in release-please github action ([#6958](https://github.com/openfoodfacts/openfoodfacts-server/issues/6958)) ([cabd3fa](https://github.com/openfoodfacts/openfoodfacts-server/commit/cabd3fa26f1ee0b9d288f938155b21d4a0899d81))
* uninitialized value ([#6912](https://github.com/openfoodfacts/openfoodfacts-server/issues/6912)) ([9f4c5ea](https://github.com/openfoodfacts/openfoodfacts-server/commit/9f4c5ea697d105558d4d8a595eabdebce5ef4cf0))
* zh_CN, pt_PT and nl_NL ([#6967](https://github.com/openfoodfacts/openfoodfacts-server/issues/6967)) ([5aebdfc](https://github.com/openfoodfacts/openfoodfacts-server/commit/5aebdfcdace255296f1a77c07bb1cb8166104847))


### Taxonomy

* Minor change ([#6911](https://github.com/openfoodfacts/openfoodfacts-server/issues/6911)) ([d1ec3f8](https://github.com/openfoodfacts/openfoodfacts-server/commit/d1ec3f824e98d7178d128b43dc8a7ab870c88935))
* More minor changes to vegetarian / vegan categories ([#6924](https://github.com/openfoodfacts/openfoodfacts-server/issues/6924)) ([a979f98](https://github.com/openfoodfacts/openfoodfacts-server/commit/a979f9813bc312953d3ac7a76d8186835b8f00c1))


### Translations

* New Crowdin translations to review and merge ([#6937](https://github.com/openfoodfacts/openfoodfacts-server/issues/6937)) ([fbd4f81](https://github.com/openfoodfacts/openfoodfacts-server/commit/fbd4f811be6a62fd9be3f89ef538a2da0c0e6430))

## [1.6.0](https://github.com/openfoodfacts/openfoodfacts-server/compare/v1.5.0...v1.6.0) (2022-06-13)


### Features

* activate agena3000 import in production ([#6886](https://github.com/openfoodfacts/openfoodfacts-server/issues/6886)) ([054ec1f](https://github.com/openfoodfacts/openfoodfacts-server/commit/054ec1fa3b7ffd8d779b2f821620fec84ba676f8))
* new OFF logo [#6866](https://github.com/openfoodfacts/openfoodfacts-server/issues/6866) ([#6885](https://github.com/openfoodfacts/openfoodfacts-server/issues/6885)) ([7354ebf](https://github.com/openfoodfacts/openfoodfacts-server/commit/7354ebfff4bdb83022ac73ee646f999e229f8561))
* small improvements to ingredients and nutrition table panels ([#6869](https://github.com/openfoodfacts/openfoodfacts-server/issues/6869)) ([154f881](https://github.com/openfoodfacts/openfoodfacts-server/commit/154f8815b351fd53692c999160cc8f3cf2f82748))
* suggest fuzzy + limit as a param ([#6887](https://github.com/openfoodfacts/openfoodfacts-server/issues/6887)) ([a6622f8](https://github.com/openfoodfacts/openfoodfacts-server/commit/a6622f86af200b74043e26329b19fdaa69edff51))


### Bug Fixes

* add back nutrition facts table title in knowledge panel ([#6867](https://github.com/openfoodfacts/openfoodfacts-server/issues/6867)) ([2085f4f](https://github.com/openfoodfacts/openfoodfacts-server/commit/2085f4f99de8a0103c47626481addcacd55edc10))
* flatten Nutri-Score and Eco-Score SVG icons ([#6872](https://github.com/openfoodfacts/openfoodfacts-server/issues/6872)) ([c7dae5c](https://github.com/openfoodfacts/openfoodfacts-server/commit/c7dae5c3342c7d4ce869ed68b5e18d72657b61a1))
* Undefined variable in search.pl ([#6877](https://github.com/openfoodfacts/openfoodfacts-server/issues/6877)) ([0a91d79](https://github.com/openfoodfacts/openfoodfacts-server/commit/0a91d79cb65fef2413e3de1b1c034810cbd32d0c))
* use correct unit for nutrients expressed in IU or %DV [#6882](https://github.com/openfoodfacts/openfoodfacts-server/issues/6882) ([#6883](https://github.com/openfoodfacts/openfoodfacts-server/issues/6883)) ([2e45a06](https://github.com/openfoodfacts/openfoodfacts-server/commit/2e45a06799bd581ee7f05c62c5eaf79509b9a561))

## [1.5.0](https://github.com/openfoodfacts/openfoodfacts-server/compare/v1.4.0...v1.5.0) (2022-06-06)


### Features

* add explanation with category in the Nutri-Score and Eco-Score knowledge panels when not applicable ([#6844](https://github.com/openfoodfacts/openfoodfacts-server/issues/6844)) ([1c95c8a](https://github.com/openfoodfacts/openfoodfacts-server/commit/1c95c8a02534a5d766db150ba08bd9e5d4d72419))
* add serving size to health knowledge panel ([#6793](https://github.com/openfoodfacts/openfoodfacts-server/issues/6793)) ([1144af5](https://github.com/openfoodfacts/openfoodfacts-server/commit/1144af53783aec5ad790b45b1af6431168dda0fd))
* expand some panels only on large devices ([#6834](https://github.com/openfoodfacts/openfoodfacts-server/issues/6834)) ([6331777](https://github.com/openfoodfacts/openfoodfacts-server/commit/6331777efd5b909fd92b061b201b13bc28b7caef)), closes [#6786](https://github.com/openfoodfacts/openfoodfacts-server/issues/6786)
* refresh the Nutri-Score and Eco-Score logos ([#6848](https://github.com/openfoodfacts/openfoodfacts-server/issues/6848)) ([a677457](https://github.com/openfoodfacts/openfoodfacts-server/commit/a677457120ebafdf7c9c2878e130cc86564dd839))
* reset preferences instead of deleting + add switch to use preferences in preferences + fix bug for unknown mandatory attributes ([#6800](https://github.com/openfoodfacts/openfoodfacts-server/issues/6800)) ([9251301](https://github.com/openfoodfacts/openfoodfacts-server/commit/9251301e57da44f30ab793ebdbe3ee05dbdff66c))
* tagline for Smoothie ([#6823](https://github.com/openfoodfacts/openfoodfacts-server/issues/6823)) ([b669661](https://github.com/openfoodfacts/openfoodfacts-server/commit/b66966108e70e051c05546430e3afe8cabc46412))


### Bug Fixes

* bigger timeout for Made Near Me generation [#6789](https://github.com/openfoodfacts/openfoodfacts-server/issues/6789) ([#6790](https://github.com/openfoodfacts/openfoodfacts-server/issues/6790)) ([a791c75](https://github.com/openfoodfacts/openfoodfacts-server/commit/a791c75404d788a98bfc753b0a497a299919b0ca))
* defining current_link ([#6817](https://github.com/openfoodfacts/openfoodfacts-server/issues/6817)) ([19e2e3c](https://github.com/openfoodfacts/openfoodfacts-server/commit/19e2e3c21f539834ba291aa2f85d18e1add0f571))
* fallback to english for knowledge panels ([#6804](https://github.com/openfoodfacts/openfoodfacts-server/issues/6804)) ([43712b5](https://github.com/openfoodfacts/openfoodfacts-server/commit/43712b50e65f31af8f2cef222344c0f189e2a62a))
* ingredients and nutrition should have titles ([#6839](https://github.com/openfoodfacts/openfoodfacts-server/issues/6839)) ([8048013](https://github.com/openfoodfacts/openfoodfacts-server/commit/8048013eaef26f7d153e37870746a51d54559850)), closes [#6835](https://github.com/openfoodfacts/openfoodfacts-server/issues/6835)
* make panel ids consistent for ingredients analysis knowledge panels ([#6815](https://github.com/openfoodfacts/openfoodfacts-server/issues/6815)) ([726fb92](https://github.com/openfoodfacts/openfoodfacts-server/commit/726fb92d75c579692d051b353cf09f92ca7fbcf4))
* prefer real user userid to app uuid #- an app userid if the app did not provide an app uuid [#6847](https://github.com/openfoodfacts/openfoodfacts-server/issues/6847) ([#6851](https://github.com/openfoodfacts/openfoodfacts-server/issues/6851)) ([367913c](https://github.com/openfoodfacts/openfoodfacts-server/commit/367913c30c28e88878ced17b45d6c7ed4e583d86))
* use mandatory food preferences for score ([#6797](https://github.com/openfoodfacts/openfoodfacts-server/issues/6797)) ([b8e36da](https://github.com/openfoodfacts/openfoodfacts-server/commit/b8e36da1b575c8787108477396db42e4f51e1f43))

## [1.4.0](https://github.com/openfoodfacts/openfoodfacts-server/compare/v1.3.0...v1.4.0) (2022-05-18)


### Features

* Add Wikidata entries to make packaging knowledge possible ([#6776](https://github.com/openfoodfacts/openfoodfacts-server/issues/6776)) ([62b157d](https://github.com/openfoodfacts/openfoodfacts-server/commit/62b157d48c1015ebf2f88233b73a5a02b1585d85))
* adding Wikidata entities for processing methods ([#6779](https://github.com/openfoodfacts/openfoodfacts-server/issues/6779)) ([562d8d1](https://github.com/openfoodfacts/openfoodfacts-server/commit/562d8d170659c4a605f07478f1a58ec7251e8475))
* check {variables} are kept in translations  ([#6709](https://github.com/openfoodfacts/openfoodfacts-server/issues/6709)) ([fdbd7f3](https://github.com/openfoodfacts/openfoodfacts-server/commit/fdbd7f3474fcd2248c270890eead67be10689c51))
* generate and send GS1 CIC confirmation messages to Agena3000 ([#6756](https://github.com/openfoodfacts/openfoodfacts-server/issues/6756)) ([b9b6f05](https://github.com/openfoodfacts/openfoodfacts-server/commit/b9b6f05a12231d0d82db06a0cf4a49f72027f30b))
* Improvements to Nutri-Score panel, remove extended Eco-Score panel ([#6748](https://github.com/openfoodfacts/openfoodfacts-server/issues/6748)) ([37c76c1](https://github.com/openfoodfacts/openfoodfacts-server/commit/37c76c12fd1ee6c61253151ee74778ffd9e7cdbc))
* link to world now keeps user language when possible ([13c725e](https://github.com/openfoodfacts/openfoodfacts-server/commit/13c725e1edb72a6a0d43a36447e86401bea5fb2a)), closes [#1437](https://github.com/openfoodfacts/openfoodfacts-server/issues/1437)
* New system to show how well products match user preferences ([#6764](https://github.com/openfoodfacts/openfoodfacts-server/issues/6764)) ([6749369](https://github.com/openfoodfacts/openfoodfacts-server/commit/6749369a3dba3d6f454e74dfe6bcdbe25eeee696))


### Bug Fixes

* assume unrecognized ingredients are not palm oil  ([#6713](https://github.com/openfoodfacts/openfoodfacts-server/issues/6713)) ([d5b9b9e](https://github.com/openfoodfacts/openfoodfacts-server/commit/d5b9b9e4c98c5fbe33563d92b7cc71349e7dadd7))
* remove synonyms from root level tags [#6763](https://github.com/openfoodfacts/openfoodfacts-server/issues/6763) ([#6769](https://github.com/openfoodfacts/openfoodfacts-server/issues/6769)) ([d56b3d6](https://github.com/openfoodfacts/openfoodfacts-server/commit/d56b3d60c37513a1d6893aa58e4e0e0daec56685))
* tests if variable defined before use ([#6724](https://github.com/openfoodfacts/openfoodfacts-server/issues/6724)) ([a112921](https://github.com/openfoodfacts/openfoodfacts-server/commit/a112921e443df8a50c32bf99283520fb0b1c9901))
* typo in product scoring ([#6792](https://github.com/openfoodfacts/openfoodfacts-server/issues/6792)) ([23a2822](https://github.com/openfoodfacts/openfoodfacts-server/commit/23a282240e3fb5654cec9fc26aa138ff33fbc3d1))

## [1.3.0](https://github.com/openfoodfacts/openfoodfacts-server/compare/v1.2.1...v1.3.0) (2022-05-09)


### Features

* add link to learn more about nutriscore + ecoscore ([#6701](https://github.com/openfoodfacts/openfoodfacts-server/issues/6701)) ([c299a55](https://github.com/openfoodfacts/openfoodfacts-server/commit/c299a558af89cd77ecf4a53f5a4be3a2021a341f))
* add support for 2 GS1 quantityContained field in nutrientDetail [#6537](https://github.com/openfoodfacts/openfoodfacts-server/issues/6537) ([#6630](https://github.com/openfoodfacts/openfoodfacts-server/issues/6630)) ([f6c2678](https://github.com/openfoodfacts/openfoodfacts-server/commit/f6c267825beeaf4509e6a2bb9aabf091340a2ddf))
* google anaytics 4 and matomo for OFF ([#6712](https://github.com/openfoodfacts/openfoodfacts-server/issues/6712)) ([7921b3e](https://github.com/openfoodfacts/openfoodfacts-server/commit/7921b3e97326d20618fc6d15180dee49f7627aaf))
* start of template for tags ([#6695](https://github.com/openfoodfacts/openfoodfacts-server/issues/6695)) ([d1ae945](https://github.com/openfoodfacts/openfoodfacts-server/commit/d1ae94572aac72f40d645bdbbf923617373963fe))


### Bug Fixes

* add UTZ Certified xx: and fr: translations ([#6749](https://github.com/openfoodfacts/openfoodfacts-server/issues/6749)) ([c6140f6](https://github.com/openfoodfacts/openfoodfacts-server/commit/c6140f6d2f007fab05ae873639f2d2fb18fa37dd))
* Dutch adds ([#6681](https://github.com/openfoodfacts/openfoodfacts-server/issues/6681)) ([9546629](https://github.com/openfoodfacts/openfoodfacts-server/commit/9546629cdd692521ae5001e3d3028ee09a0da798))
* Ingredient parsing improvement for additives ([#6569](https://github.com/openfoodfacts/openfoodfacts-server/issues/6569)) ([f994a08](https://github.com/openfoodfacts/openfoodfacts-server/commit/f994a089e295c27787f66f32d2e5f2cec7deb2c3))
* limit userid to 20 characters and usernames to 60 char. ([#6631](https://github.com/openfoodfacts/openfoodfacts-server/issues/6631)) ([29a739b](https://github.com/openfoodfacts/openfoodfacts-server/commit/29a739b94aff3cba48dae587a8be63d7af716e51))
* non ambiguous translation for palm oil content unknown [#6698](https://github.com/openfoodfacts/openfoodfacts-server/issues/6698) ([#6699](https://github.com/openfoodfacts/openfoodfacts-server/issues/6699)) ([2e621b3](https://github.com/openfoodfacts/openfoodfacts-server/commit/2e621b31d425b147fa55f83fe6d816b8d2bad0d4))
* options for gulp-svgmin/svgo icons [#6706](https://github.com/openfoodfacts/openfoodfacts-server/issues/6706) ([#6707](https://github.com/openfoodfacts/openfoodfacts-server/issues/6707)) ([5bb7a26](https://github.com/openfoodfacts/openfoodfacts-server/commit/5bb7a268df01dbaea0513c4cc934262dff6ae0b1))
* undefined variable warning ([#6656](https://github.com/openfoodfacts/openfoodfacts-server/issues/6656)) ([127e0c0](https://github.com/openfoodfacts/openfoodfacts-server/commit/127e0c0135771fe5178a309d80730fac262ab4b3))
* unlocalized knowledge panel string for Smoothie ([#6682](https://github.com/openfoodfacts/openfoodfacts-server/issues/6682)) ([f58b3c8](https://github.com/openfoodfacts/openfoodfacts-server/commit/f58b3c8f90b5fa139117471072821a611d133001))
* untranslated string: "Impact for this product" ([#6670](https://github.com/openfoodfacts/openfoodfacts-server/issues/6670)) ([13a571c](https://github.com/openfoodfacts/openfoodfacts-server/commit/13a571cf3de0e6f034b96a69d4f32eac7312555b)), closes [#6629](https://github.com/openfoodfacts/openfoodfacts-server/issues/6629)

### [1.2.1](https://github.com/openfoodfacts/openfoodfacts-server/compare/v1.2.0...v1.2.1) (2022-04-21)


### Bug Fixes

* "Dry" not being recognized as a processing type ([#6636](https://github.com/openfoodfacts/openfoodfacts-server/issues/6636)) ([554f69a](https://github.com/openfoodfacts/openfoodfacts-server/commit/554f69a94c65fda685611c15ba8a576fa90a32b3))
* Add check for the definition of $user_ref->{org} ([#6637](https://github.com/openfoodfacts/openfoodfacts-server/issues/6637)) ([b9d4fce](https://github.com/openfoodfacts/openfoodfacts-server/commit/b9d4fce7e531cfd24a4324e82b0b4b558e802df9))
* Dutch inspired additions ([#6626](https://github.com/openfoodfacts/openfoodfacts-server/issues/6626)) ([9db6d86](https://github.com/openfoodfacts/openfoodfacts-server/commit/9db6d86f1efde005ed87ad76ba396192adbf038b))
* French translation Typo ([#6652](https://github.com/openfoodfacts/openfoodfacts-server/issues/6652)) ([c408d5c](https://github.com/openfoodfacts/openfoodfacts-server/commit/c408d5c8779c416796c3574ffdb38c2d53f74b10))
* move h1 tags to template ([#6654](https://github.com/openfoodfacts/openfoodfacts-server/issues/6654)) ([b3b482b](https://github.com/openfoodfacts/openfoodfacts-server/commit/b3b482b931b3f4f6fe5731011ce763f4591a2550))
* warning message ([#6633](https://github.com/openfoodfacts/openfoodfacts-server/issues/6633)) ([d1b1af5](https://github.com/openfoodfacts/openfoodfacts-server/commit/d1b1af58e64b4a234951c774e3e93680882b5218))
* Wikidata entries to update ([#6619](https://github.com/openfoodfacts/openfoodfacts-server/issues/6619)) ([383ab3e](https://github.com/openfoodfacts/openfoodfacts-server/commit/383ab3e3c6ce63294447d9645bb3511e2328804e))

## [1.2.0](https://github.com/openfoodfacts/openfoodfacts-server/compare/v1.1.0...v1.2.0) (2022-04-15)


### Features

* Agena3000 integration ([#6594](https://github.com/openfoodfacts/openfoodfacts-server/issues/6594)) ([a6841ea](https://github.com/openfoodfacts/openfoodfacts-server/commit/a6841eaf2b5a312121c4cd51435d24700244f5ad))
* Improvements to GS1 imports to prepare integration of Agena3000 ([#6566](https://github.com/openfoodfacts/openfoodfacts-server/issues/6566)) ([ce4eb51](https://github.com/openfoodfacts/openfoodfacts-server/commit/ce4eb51a3817774a9912209e8a67508ff785b7df))


### Bug Fixes

* Add explicit labels (using: for & id) to input fields  ([#6577](https://github.com/openfoodfacts/openfoodfacts-server/issues/6577)) ([1c10126](https://github.com/openfoodfacts/openfoodfacts-server/commit/1c1012680da820690a611ccb171863f3dddc378f))
* Adds missing double quote to the href attribute ([#6573](https://github.com/openfoodfacts/openfoodfacts-server/issues/6573)) ([d875e06](https://github.com/openfoodfacts/openfoodfacts-server/commit/d875e062cc4d202aaf10c75645493ff0369a7e84))
* check for user creation spam  ([#6616](https://github.com/openfoodfacts/openfoodfacts-server/issues/6616)) ([477bfd9](https://github.com/openfoodfacts/openfoodfacts-server/commit/477bfd96ba5edcdb8029117117acb6f612111635))
* Dutch additions ([#6523](https://github.com/openfoodfacts/openfoodfacts-server/issues/6523)) ([e36c2af](https://github.com/openfoodfacts/openfoodfacts-server/commit/e36c2af577dbdd89bb033074185a6d3066a4cfab))
* Dutch next round of improvements ([#6556](https://github.com/openfoodfacts/openfoodfacts-server/issues/6556)) ([df5d391](https://github.com/openfoodfacts/openfoodfacts-server/commit/df5d391c2dbf540c0df10f1adbe683ecaf33eb74))
* Email address with space ([#6578](https://github.com/openfoodfacts/openfoodfacts-server/issues/6578)) ([7469115](https://github.com/openfoodfacts/openfoodfacts-server/commit/74691151f648c7e87247674a90f6cc53d68cdfaa))
* Give priority to ingredients over category to estimate fruits/vegetable content for Nutri-Score ([#6600](https://github.com/openfoodfacts/openfoodfacts-server/issues/6600)) ([20bf2b3](https://github.com/openfoodfacts/openfoodfacts-server/commit/20bf2b38f1db437a72467d78b4e9309d4f432b2a)), closes [#6598](https://github.com/openfoodfacts/openfoodfacts-server/issues/6598)
* languages and nutrients taxonomies ([#6553](https://github.com/openfoodfacts/openfoodfacts-server/issues/6553)) ([c4fb6fa](https://github.com/openfoodfacts/openfoodfacts-server/commit/c4fb6fa5e165713a2c9ba9b8e4e24be5c4bb6983))
* make old checks pass until de-activation ([3e73c88](https://github.com/openfoodfacts/openfoodfacts-server/commit/3e73c887d4e0613bbcc49720aaf1ee49b8001aa9))
* Makes "Unselect Image" button translatable ([#6570](https://github.com/openfoodfacts/openfoodfacts-server/issues/6570)) ([4bc1179](https://github.com/openfoodfacts/openfoodfacts-server/commit/4bc1179e2d3b1687e742e6b913636b81dd350546))
* more precise estimate of ingredients percents min and max ([#6614](https://github.com/openfoodfacts/openfoodfacts-server/issues/6614)) ([325b418](https://github.com/openfoodfacts/openfoodfacts-server/commit/325b418294d6bc3da79b9b583aa729f36133abe9))
* Remove duplicate string ([#6544](https://github.com/openfoodfacts/openfoodfacts-server/issues/6544)) ([a950cda](https://github.com/openfoodfacts/openfoodfacts-server/commit/a950cda609426841d9b597ca6314c10262860507))
* remove Top 10 Issue github action - [#6518](https://github.com/openfoodfacts/openfoodfacts-server/issues/6518) ([#6519](https://github.com/openfoodfacts/openfoodfacts-server/issues/6519)) ([fc36d1b](https://github.com/openfoodfacts/openfoodfacts-server/commit/fc36d1ba0c2c5cb9b1a301f3f36becebf136c269))
* Setting param to return scalar ([#6613](https://github.com/openfoodfacts/openfoodfacts-server/issues/6613)) ([9e80edf](https://github.com/openfoodfacts/openfoodfacts-server/commit/9e80edfc0b1ed29ccfb2dd99ead239239e3a18f0))
* Skip fourth header line in agribalyse csv ([#6568](https://github.com/openfoodfacts/openfoodfacts-server/issues/6568)) ([915716d](https://github.com/openfoodfacts/openfoodfacts-server/commit/915716d2ee689888ae4167292a1dd40b061e919b))
* titles for knowledge panels cards [#6590](https://github.com/openfoodfacts/openfoodfacts-server/issues/6590) ([#6593](https://github.com/openfoodfacts/openfoodfacts-server/issues/6593)) ([0080f6b](https://github.com/openfoodfacts/openfoodfacts-server/commit/0080f6b80b5dd101ff67943cf85cc599fdd7d1d0))
* uninitialized value update ([#6514](https://github.com/openfoodfacts/openfoodfacts-server/issues/6514)) - outreachy ([2fc8e67](https://github.com/openfoodfacts/openfoodfacts-server/commit/2fc8e672fd051097290ee6be5cd678b0fab0a043))
* use prepared nutrition values to compute nutriscore of cocoa and chocolate powders ([#6552](https://github.com/openfoodfacts/openfoodfacts-server/issues/6552)) ([fceefac](https://github.com/openfoodfacts/openfoodfacts-server/commit/fceefac6896889f2c048e69219b21e52f7296e48))

## [1.1.0](https://github.com/openfoodfacts/openfoodfacts-server/compare/v1.0.0...v1.1.0) (2022-04-01)


### Features

* allow barcode and edit link in search results ([#6494](https://github.com/openfoodfacts/openfoodfacts-server/issues/6494)) ([41fe83f](https://github.com/openfoodfacts/openfoodfacts-server/commit/41fe83f9059d36806fd8d61a0ba2736d2c543fd2)), closes [#5994](https://github.com/openfoodfacts/openfoodfacts-server/issues/5994)
* Dutch additions ([#6498](https://github.com/openfoodfacts/openfoodfacts-server/issues/6498)) ([ef4db01](https://github.com/openfoodfacts/openfoodfacts-server/commit/ef4db0115f301a9f109020426e9affd747dfedc2))
* export ecoscore fields ([#6467](https://github.com/openfoodfacts/openfoodfacts-server/issues/6467)) ([00bdd9e](https://github.com/openfoodfacts/openfoodfacts-server/commit/00bdd9e444544e2b702c80ef5b16d9ba6f673e62))
* knowledge panel to display the ingredients that make a product not vegan / vegetarian / palm oil free ([#6420](https://github.com/openfoodfacts/openfoodfacts-server/issues/6420)) ([27b7137](https://github.com/openfoodfacts/openfoodfacts-server/commit/27b7137cbb6ce982454fd1b2d218ad81db8058e6))
* link product attributes to knowledge panels ([#6493](https://github.com/openfoodfacts/openfoodfacts-server/issues/6493)) ([4950f97](https://github.com/openfoodfacts/openfoodfacts-server/commit/4950f97b2dba8fc64358a1da93a01a66ba3362e2))
* more flexible exports ([#6483](https://github.com/openfoodfacts/openfoodfacts-server/issues/6483)) ([a636491](https://github.com/openfoodfacts/openfoodfacts-server/commit/a63649131a006de9242ab7e7a00e3893e4c053ca))
* Record the reasons for NOVA classification of a product and add a NOVA knowledge panel ([#6510](https://github.com/openfoodfacts/openfoodfacts-server/issues/6510)) ([bbf14bc](https://github.com/openfoodfacts/openfoodfacts-server/commit/bbf14bc7b99d1be29687188363ac37174a7dabcb))
* Refactor CSV exports, add tests, export Eco-Score fields ([#6444](https://github.com/openfoodfacts/openfoodfacts-server/issues/6444)) ([96d31df](https://github.com/openfoodfacts/openfoodfacts-server/commit/96d31df70a4914b240c66a73d35f436f63093af7))
* Switch to the new FAQ system ([#6461](https://github.com/openfoodfacts/openfoodfacts-server/issues/6461)) ([3c40a1b](https://github.com/openfoodfacts/openfoodfacts-server/commit/3c40a1b2bf9ce9339c7e56b69b5bf9666bd907a5))


### Bug Fixes

* Add tests for Carrefour France import, + solve serving_size bug ([#6476](https://github.com/openfoodfacts/openfoodfacts-server/issues/6476)) ([f255f30](https://github.com/openfoodfacts/openfoodfacts-server/commit/f255f3061217de4edbf619ce178804eb55dfb050))
* Cleaning ingredients ([#6472](https://github.com/openfoodfacts/openfoodfacts-server/issues/6472)) ([ebddf2b](https://github.com/openfoodfacts/openfoodfacts-server/commit/ebddf2b05a4337530fd6fdc3fa62dc19ff1c44fc))
* Dutch finetuning ([#6418](https://github.com/openfoodfacts/openfoodfacts-server/issues/6418)) ([ed59464](https://github.com/openfoodfacts/openfoodfacts-server/commit/ed5946495d8a6b1f2845258ef0988e77265ab05d))
* fix image upload buttons - [#173](https://github.com/openfoodfacts/openfoodfacts-server/issues/173) ([#6485](https://github.com/openfoodfacts/openfoodfacts-server/issues/6485)) ([c747d50](https://github.com/openfoodfacts/openfoodfacts-server/commit/c747d507283f3532b9f3bc1992f0e5c37a8f36f1))
* fix states and countries taxonomies, build taxonomies ([#6442](https://github.com/openfoodfacts/openfoodfacts-server/issues/6442)) ([17faad1](https://github.com/openfoodfacts/openfoodfacts-server/commit/17faad1a655ad05d794a3adeab0ff34ba5269c74))
* handle both absolute and relative percent values for sub-ingredients ([#6528](https://github.com/openfoodfacts/openfoodfacts-server/issues/6528)) ([04bdb4e](https://github.com/openfoodfacts/openfoodfacts-server/commit/04bdb4e8ee9f23e7a8cb810883c6f1b36e65cb1b))
* Import serving size bug ([#6474](https://github.com/openfoodfacts/openfoodfacts-server/issues/6474)) ([ee2ee44](https://github.com/openfoodfacts/openfoodfacts-server/commit/ee2ee44699933cbb546b953fa21f77faf32ac6ca))
* ingredient doubles ([#6419](https://github.com/openfoodfacts/openfoodfacts-server/issues/6419)) ([764bbbc](https://github.com/openfoodfacts/openfoodfacts-server/commit/764bbbcd86e2482b9abfdd3a82d960bd78832c9d))
* ingredient doubles continues ([#6433](https://github.com/openfoodfacts/openfoodfacts-server/issues/6433)) ([ec77a78](https://github.com/openfoodfacts/openfoodfacts-server/commit/ec77a782631701af3db2aa799789214b7e5a2cce))
* release please should trigger actions ([#6503](https://github.com/openfoodfacts/openfoodfacts-server/issues/6503)) ([5d9836d](https://github.com/openfoodfacts/openfoodfacts-server/commit/5d9836dadbc9f87cc48f4777d1b84a3687054f42))
* remove obsolete strings & remove duplicate strings ([#6440](https://github.com/openfoodfacts/openfoodfacts-server/issues/6440)) ([4a2dfd1](https://github.com/openfoodfacts/openfoodfacts-server/commit/4a2dfd16221f27893d8decbc68a5284a91ee4e8b))
* Translation doubles 4 ([#6412](https://github.com/openfoodfacts/openfoodfacts-server/issues/6412)) ([69a6549](https://github.com/openfoodfacts/openfoodfacts-server/commit/69a65490909df062bd19011482a7cde44822605a))
* untranslated string for Smoothie ([#6492](https://github.com/openfoodfacts/openfoodfacts-server/issues/6492)) ([ffe58a2](https://github.com/openfoodfacts/openfoodfacts-server/commit/ffe58a2392616b1b2ea0821cdace66b6495c3919))

## 1.0.0 (2022-02-10)


### Features

* add allergens and traces to ingredients panel ([#6266](https://github.com/openfoodfacts/openfoodfacts-server/issues/6266)) ([686f4fd](https://github.com/openfoodfacts/openfoodfacts-server/commit/686f4fdf5d2b26209581c91050c7c7fc08845814))
* Add auto-labelling to PRs ([#6216](https://github.com/openfoodfacts/openfoodfacts-server/issues/6216)) ([6e430e2](https://github.com/openfoodfacts/openfoodfacts-server/commit/6e430e2a7d96b9c198166e0341698509c15b1802))
* add evaluations to nutrition facts table knowledge panel ([#6152](https://github.com/openfoodfacts/openfoodfacts-server/issues/6152)) ([41cd8b2](https://github.com/openfoodfacts/openfoodfacts-server/commit/41cd8b235d5939fec421800e34ac3e994f524b99))
* Add f_lang function to emulate python f-strings for translations ([#5962](https://github.com/openfoodfacts/openfoodfacts-server/issues/5962)) ([435f898](https://github.com/openfoodfacts/openfoodfacts-server/commit/435f89812f90e6805176b7aef0b2a34bf15f0612))
* add fruits-vegetables-nuts-estimate-from-ingredients to CSV export ([#6013](https://github.com/openfoodfacts/openfoodfacts-server/issues/6013)) ([8e986b5](https://github.com/openfoodfacts/openfoodfacts-server/commit/8e986b507d47a0a51f2f6c22fbff7ec41e407bd0))
* add fruits-vegetables-nuts-estimate-from-ingredients to CSV export [#6004](https://github.com/openfoodfacts/openfoodfacts-server/issues/6004) ([8e986b5](https://github.com/openfoodfacts/openfoodfacts-server/commit/8e986b507d47a0a51f2f6c22fbff7ec41e407bd0))
* add Grafana deployment annotation ([9fb1f2a](https://github.com/openfoodfacts/openfoodfacts-server/commit/9fb1f2adb1b4d3a1d7f17fb62fedafd80f8a0c55))
* add include_root_entries option to taxonomy API, fixes [#6039](https://github.com/openfoodfacts/openfoodfacts-server/issues/6039) ([#6040](https://github.com/openfoodfacts/openfoodfacts-server/issues/6040)) ([7bcbcb7](https://github.com/openfoodfacts/openfoodfacts-server/commit/7bcbcb7ca1e59ad6d0703133b0cef9e320b0fb8e))
* add mongodb metrics exporter ([bce8205](https://github.com/openfoodfacts/openfoodfacts-server/commit/bce8205d9586694d2d27c4c53a4d241decaf6a87))
* add panel_group element and environment_card panel ([#5958](https://github.com/openfoodfacts/openfoodfacts-server/issues/5958)) ([e10ec23](https://github.com/openfoodfacts/openfoodfacts-server/commit/e10ec233c62ad3d727eb9dee68ef7cd55a7a8fb5))
* add repo interoperability ([48522db](https://github.com/openfoodfacts/openfoodfacts-server/commit/48522dbc59e9841a92e9a6a5061dc1c31b8b24e1))
* add script to export products data and images for docker dev ([#6010](https://github.com/openfoodfacts/openfoodfacts-server/issues/6010)) ([a3d1a55](https://github.com/openfoodfacts/openfoodfacts-server/commit/a3d1a5551c70c6c163bd59988feb9ec6a93812c7))
* Add Top Issues ([#6217](https://github.com/openfoodfacts/openfoodfacts-server/issues/6217)) ([a1acd8d](https://github.com/openfoodfacts/openfoodfacts-server/commit/a1acd8d178518252c5b6d5845a2cf1a5a5dcd8cc))
* Add Wikidata items to categories ([#5805](https://github.com/openfoodfacts/openfoodfacts-server/issues/5805)) ([d71eee3](https://github.com/openfoodfacts/openfoodfacts-server/commit/d71eee339b7dc62ef2f2968974f4c4ff6c1075bf))
* Categories taxonomy improvements for Wikidata and IGPs ([#6196](https://github.com/openfoodfacts/openfoodfacts-server/issues/6196)) ([b854c27](https://github.com/openfoodfacts/openfoodfacts-server/commit/b854c27810b8d970d6cb45c567b43449217e0ef0))
* different Nutri-Score icons and text for unknown and not-applicable  ([#6278](https://github.com/openfoodfacts/openfoodfacts-server/issues/6278)) ([ccdd01b](https://github.com/openfoodfacts/openfoodfacts-server/commit/ccdd01bd1dc99a537c791f0fadf6609d4e4d3e23))
* dynamic assets generation in dev mode ([4c0c5bd](https://github.com/openfoodfacts/openfoodfacts-server/commit/4c0c5bda5ac2a9df8a7f462895c0babd63f04a2e))
* dynamic assets generation in dev mode, fixes [#5846](https://github.com/openfoodfacts/openfoodfacts-server/issues/5846) ([2370e21](https://github.com/openfoodfacts/openfoodfacts-server/commit/2370e214aac0b64ae6c8dda03c9679d5c63458d0))
* example product in API with code=example - [#6250](https://github.com/openfoodfacts/openfoodfacts-server/issues/6250) ([#6252](https://github.com/openfoodfacts/openfoodfacts-server/issues/6252)) ([c0605a4](https://github.com/openfoodfacts/openfoodfacts-server/commit/c0605a4e7a40a8ac2b39c28e6007f95ffb150dba))
* Experimental extended Eco-Score panel ([#6314](https://github.com/openfoodfacts/openfoodfacts-server/issues/6314)) ([de82954](https://github.com/openfoodfacts/openfoodfacts-server/commit/de8295462984397b0407579a77beb001789e95a9))
* Extract ingredients origins from labels and use them in Eco-Score ([#6377](https://github.com/openfoodfacts/openfoodfacts-server/issues/6377)) ([d5bd976](https://github.com/openfoodfacts/openfoodfacts-server/commit/d5bd97628522f8db5944df35877d230b36e23ec9))
* Finalize Eco-Score knowledge panels ([#6017](https://github.com/openfoodfacts/openfoodfacts-server/issues/6017)) ([b14375d](https://github.com/openfoodfacts/openfoodfacts-server/commit/b14375dd93c29a56fa34ada2a4d9eb24cbe11d61))
* Fix and improve detection of apps (name and UUID) to populate data sources ([#6319](https://github.com/openfoodfacts/openfoodfacts-server/issues/6319)) ([0092e2e](https://github.com/openfoodfacts/openfoodfacts-server/commit/0092e2e0a119290742574bf7e8de8d52d58ea6d9))
* Initial support for specific ingredients parsing ([#6243](https://github.com/openfoodfacts/openfoodfacts-server/issues/6243)) ([f69e9a9](https://github.com/openfoodfacts/openfoodfacts-server/commit/f69e9a90e349bf6b04c3c02a5601aec47e14f807))
* Knowledge panels for labels ([#5950](https://github.com/openfoodfacts/openfoodfacts-server/issues/5950)) ([a64919c](https://github.com/openfoodfacts/openfoodfacts-server/commit/a64919c36c10a507516f5567114eb0eae76b9c29))
* manufacturing place + origins of ingredients knowledge panels + Normalize all panels ([#6069](https://github.com/openfoodfacts/openfoodfacts-server/issues/6069)) ([d37011a](https://github.com/openfoodfacts/openfoodfacts-server/commit/d37011a49cc816bcb2722222dbaad3ed171d1482))
* Palm oil knowledge panel ([#5968](https://github.com/openfoodfacts/openfoodfacts-server/issues/5968)) ([8cd1f22](https://github.com/openfoodfacts/openfoodfacts-server/commit/8cd1f22d10b96f1047b6340428e9167b37a7af0c))
* **producers:** add link to admin manual on session sucess ([#6267](https://github.com/openfoodfacts/openfoodfacts-server/issues/6267)) ([ea37ad7](https://github.com/openfoodfacts/openfoodfacts-server/commit/ea37ad726df1622e33a86e76bc92933c7afef0d8))
* refactor Eco-Score knowledge panels + accordion display on web ([#5841](https://github.com/openfoodfacts/openfoodfacts-server/issues/5841)) ([ecc8539](https://github.com/openfoodfacts/openfoodfacts-server/commit/ecc85397549be72e7fb9166087cdd8738a4902ec))
* start of additives panels ([#6270](https://github.com/openfoodfacts/openfoodfacts-server/issues/6270)) ([7f9ac03](https://github.com/openfoodfacts/openfoodfacts-server/commit/7f9ac03c05a217e5fd8b15307b9a162fe8a31a35))


### Bug Fixes

* add countries correctly in scanbot ([#6014](https://github.com/openfoodfacts/openfoodfacts-server/issues/6014)) ([7dceea2](https://github.com/openfoodfacts/openfoodfacts-server/commit/7dceea2df879a5bfeb1f86884b9d48f7a56e8a75))
* add postgres_exporter, unexpose postgres port ([270c977](https://github.com/openfoodfacts/openfoodfacts-server/commit/270c97773ac8b1fafd2ca28ed4a574ddb77517eb))
* added norway logo so that tests passes ([7c4e506](https://github.com/openfoodfacts/openfoodfacts-server/commit/7c4e506f0b12a466f25c0a2ace23f8859f31d759))
* allow unchecking checked boxes in product edit form ([#6203](https://github.com/openfoodfacts/openfoodfacts-server/issues/6203)) ([dd25800](https://github.com/openfoodfacts/openfoodfacts-server/commit/dd25800e8e16f25282be90bc43d0fe4cf2c388fa))
* change string to boolean for expanded knowledge panel ([#6081](https://github.com/openfoodfacts/openfoodfacts-server/issues/6081)) ([b05e668](https://github.com/openfoodfacts/openfoodfacts-server/commit/b05e6683b96aac465b19fc608b6b780ddec25f66))
* changed some log levels to debug ([#6335](https://github.com/openfoodfacts/openfoodfacts-server/issues/6335)) ([085b2e6](https://github.com/openfoodfacts/openfoodfacts-server/commit/085b2e6623cb8ccf66b370e5bd75adca337ac224))
* correct errors in labels taxonomy ([#6392](https://github.com/openfoodfacts/openfoodfacts-server/issues/6392)) ([c6119d4](https://github.com/openfoodfacts/openfoodfacts-server/commit/c6119d4c4874d50de1f6046c81512642357e1383))
* correct nesting of cgi/nutrient.pl API response [#5997](https://github.com/openfoodfacts/openfoodfacts-server/issues/5997) ([4367016](https://github.com/openfoodfacts/openfoodfacts-server/commit/43670163d2f277469a2163daccf2db98e758d4a4))
* create directory for stats files if needed ([#6208](https://github.com/openfoodfacts/openfoodfacts-server/issues/6208)) ([4326c50](https://github.com/openfoodfacts/openfoodfacts-server/commit/4326c50a418f8271e44e808b1a8f1b16aff639d9))
* details of improvements oppportunities ([#6359](https://github.com/openfoodfacts/openfoodfacts-server/issues/6359)) ([b740fc0](https://github.com/openfoodfacts/openfoodfacts-server/commit/b740fc0a46abbbc6a9f46c4ddc1916f469655a63))
* docker networks in prod after exporters crashing ([24862e8](https://github.com/openfoodfacts/openfoodfacts-server/commit/24862e829b2e0038bd445c6ffefc5d5b7f776472))
* docker networks in prod after exporters crashing ([436587e](https://github.com/openfoodfacts/openfoodfacts-server/commit/436587e2ef8e86d2fd7495341eeb1a6531593164))
* ensure windows newlines don't break panels ([#6254](https://github.com/openfoodfacts/openfoodfacts-server/issues/6254)) ([74e9b3a](https://github.com/openfoodfacts/openfoodfacts-server/commit/74e9b3a5d166b7da5fc4d8c9fe6ee1b5d5e839a0))
* fix daily tasks ([#6227](https://github.com/openfoodfacts/openfoodfacts-server/issues/6227)) ([5f9c7c7](https://github.com/openfoodfacts/openfoodfacts-server/commit/5f9c7c774da4c1d6d0934044aeddcd2c2e74bb56))
* fix gulpfile ([#5988](https://github.com/openfoodfacts/openfoodfacts-server/issues/5988)) ([bbe0e4f](https://github.com/openfoodfacts/openfoodfacts-server/commit/bbe0e4f631009b2016feb461d1b5464d90cab2b7))
* fix log level config handling ([344a7aa](https://github.com/openfoodfacts/openfoodfacts-server/commit/344a7aae899dd852c64cf75b065b030645aafca1))
* fixes to have build_lang running ([c99538b](https://github.com/openfoodfacts/openfoodfacts-server/commit/c99538bfa875bde9694aa4e6f5429c3984dc7c65))
* French translation for appetizers ([#6253](https://github.com/openfoodfacts/openfoodfacts-server/issues/6253)) ([bcbc70c](https://github.com/openfoodfacts/openfoodfacts-server/commit/bcbc70ccf130db0cff7f391816f32e6b5a8cfedd))
* identify lecitina de girasol additive and make emulsifiers Nova 4 ([#5972](https://github.com/openfoodfacts/openfoodfacts-server/issues/5972)) ([9022c0e](https://github.com/openfoodfacts/openfoodfacts-server/commit/9022c0eaf3b5dcd90e555449819bd69412b2619e))
* increase timeout for gen_top_tags_per_country.pl - fixes [#6244](https://github.com/openfoodfacts/openfoodfacts-server/issues/6244) ([#6246](https://github.com/openfoodfacts/openfoodfacts-server/issues/6246)) ([35d4d24](https://github.com/openfoodfacts/openfoodfacts-server/commit/35d4d248cefd89c3800d86ec369f620e0a34d38d))
* keep eol to lf as default ([#6220](https://github.com/openfoodfacts/openfoodfacts-server/issues/6220)) ([e4a2911](https://github.com/openfoodfacts/openfoodfacts-server/commit/e4a29117a44bca7a96e216d32282d20392446e6e))
* link to edited product - fixes [#5954](https://github.com/openfoodfacts/openfoodfacts-server/issues/5954) ([#5963](https://github.com/openfoodfacts/openfoodfacts-server/issues/5963)) ([942fd34](https://github.com/openfoodfacts/openfoodfacts-server/commit/942fd348fa89a7a8cd720976fa4984047276b016))
* links to previous revisions in product edit form ([#6336](https://github.com/openfoodfacts/openfoodfacts-server/issues/6336)) ([240489f](https://github.com/openfoodfacts/openfoodfacts-server/commit/240489f25eb3ba245b7f97e88000a6de179bb5a9))
* Localize Eco-Score soon enough + add 'world' Eco-Score. ([#6105](https://github.com/openfoodfacts/openfoodfacts-server/issues/6105)) ([0621b94](https://github.com/openfoodfacts/openfoodfacts-server/commit/0621b94bcaeb1f4f157a04e8cc214fdc201202d7))
* make incron work as non root ([24746d3](https://github.com/openfoodfacts/openfoodfacts-server/commit/24746d31814c336c388b09a2192492d52e463865))
<<<<<<< HEAD
* Make maybe vegan/vegetarian attribute score 50 instead of 20 ([#5839](https://github.com/openfoodfacts/openfoodfacts-server/issues/5839)) ([70ea2e1](https://github.com/openfoodfacts/openfoodfacts-server/commit/70ea2e1086192c2645280cec0d262e31fa72b819))
=======
>>>>>>> 6eb97003f551acf5a5ee285a9717f1b660c9a46d
* match UID in Dockerfile with user uid in servers ([2182532](https://github.com/openfoodfacts/openfoodfacts-server/commit/2182532ec2308389765d07e7bb1ba1212a3cd4ae))
* normalize code for /products endpoint [#6024](https://github.com/openfoodfacts/openfoodfacts-server/issues/6024) ([#6026](https://github.com/openfoodfacts/openfoodfacts-server/issues/6026)) ([640f6b5](https://github.com/openfoodfacts/openfoodfacts-server/commit/640f6b5420a179221914493afab2ad4d89cfb383))
* npm run prepare issue ([290b71a](https://github.com/openfoodfacts/openfoodfacts-server/commit/290b71a084306166de4ff2abd10764e9cb273236))
* npm run prepare issue ([fb3479a](https://github.com/openfoodfacts/openfoodfacts-server/commit/fb3479adbbd47c3580e4861aa8472e8649c0b6aa))
* product images ownership ([d2aff77](https://github.com/openfoodfacts/openfoodfacts-server/commit/d2aff77d9916123fd0f3f8b7b7b15c60533f9637))
* product images ownership ([642cc8c](https://github.com/openfoodfacts/openfoodfacts-server/commit/642cc8c5f5d07ed75834bc4b64efaa587c696941))
* product_images location was wrong ([5278808](https://github.com/openfoodfacts/openfoodfacts-server/commit/5278808d8cd82572bedaf7be7ac151ae202d28c9))
* put back compiled templates dir in data_root/tmp ([#6129](https://github.com/openfoodfacts/openfoodfacts-server/issues/6129)) ([e156c1c](https://github.com/openfoodfacts/openfoodfacts-server/commit/e156c1c35e26932a2349388412cb665a2a42e287))
* quote some strings in knowledge panel JSON output ([#6076](https://github.com/openfoodfacts/openfoodfacts-server/issues/6076)) ([d9ebe60](https://github.com/openfoodfacts/openfoodfacts-server/commit/d9ebe601909cb9ddf1ff47992f34984532600bc6))
* Remove empty POT-Creation-Date in hu.po ([#6008](https://github.com/openfoodfacts/openfoodfacts-server/issues/6008)) ([e8e1ec0](https://github.com/openfoodfacts/openfoodfacts-server/commit/e8e1ec02fbffddaba070c4cdeef20fcf679144b7))
* remove external volumes for ones that need re-creation ([dbdd4be](https://github.com/openfoodfacts/openfoodfacts-server/commit/dbdd4bef8fa09462eb4fe2cc33fba0d78e5f5ebe))
* remove MONGO_INIT_ROOT_USERNAME/PASSWORD as it breaks the dev workflow" ([#6127](https://github.com/openfoodfacts/openfoodfacts-server/issues/6127)) ([494e0c5](https://github.com/openfoodfacts/openfoodfacts-server/commit/494e0c5ccd873ec810e88d9813e9bf7d7a28e40c))
* rename type to tagtype in taxonomy API ([#5953](https://github.com/openfoodfacts/openfoodfacts-server/issues/5953)) ([d8cf36a](https://github.com/openfoodfacts/openfoodfacts-server/commit/d8cf36ae46a457c4d438d95758704aee22c06448))
* set language of fields during init, fixes [#6310](https://github.com/openfoodfacts/openfoodfacts-server/issues/6310) ([#6311](https://github.com/openfoodfacts/openfoodfacts-server/issues/6311)) ([8c2886f](https://github.com/openfoodfacts/openfoodfacts-server/commit/8c2886f0818736dc774e515b24f8b82a4a41d091))
* show 'we need your help' message for ingredients analysis only when needed - fixes [#6341](https://github.com/openfoodfacts/openfoodfacts-server/issues/6341) ([#6342](https://github.com/openfoodfacts/openfoodfacts-server/issues/6342)) ([9e001c1](https://github.com/openfoodfacts/openfoodfacts-server/commit/9e001c199530b626a2e42ec31b665bd4dd1669c8))
* the backend needs write access to product images ([#6011](https://github.com/openfoodfacts/openfoodfacts-server/issues/6011)) ([5278808](https://github.com/openfoodfacts/openfoodfacts-server/commit/5278808d8cd82572bedaf7be7ac151ae202d28c9))
* tmpfs is for tmp :-) ([f1599b5](https://github.com/openfoodfacts/openfoodfacts-server/commit/f1599b560ebadd75c936c58056c548d84cdf1ddb))
* try lowercased email on login ([1e2342f](https://github.com/openfoodfacts/openfoodfacts-server/commit/1e2342fbf9f6bc6191fd2092fce0f15c73bb7e94))
* trying to fix problems with pathes and volumes ([be14135](https://github.com/openfoodfacts/openfoodfacts-server/commit/be14135c02068f635f4b6cc58ef0fbc34f32626a))
* turn relative links to absolute links in knowledge panels ([#6353](https://github.com/openfoodfacts/openfoodfacts-server/issues/6353)) ([7be647d](https://github.com/openfoodfacts/openfoodfacts-server/commit/7be647dd490118a04b6d15ffb94f33071c60f1b6))
* typo fix on developing ([#6324](https://github.com/openfoodfacts/openfoodfacts-server/issues/6324)) ([0a6d637](https://github.com/openfoodfacts/openfoodfacts-server/commit/0a6d63727606d61d39f2a4233421968ec069a00c))
* typo in function name in Food.pm [#6288](https://github.com/openfoodfacts/openfoodfacts-server/issues/6288) [#6287](https://github.com/openfoodfacts/openfoodfacts-server/issues/6287) ([#6291](https://github.com/openfoodfacts/openfoodfacts-server/issues/6291)) ([20d3228](https://github.com/openfoodfacts/openfoodfacts-server/commit/20d32283cd47187ca06a007e9cfe9e045ecf4276))
* unexpose postgres port ([29165df](https://github.com/openfoodfacts/openfoodfacts-server/commit/29165dfd5ada5e3f2a7c019acebdb75f9995656b))
* update log.conf to match production settings ([8d8b622](https://github.com/openfoodfacts/openfoodfacts-server/commit/8d8b622d361f367e797ecd513d39940099ea9b9c))
* use /tmp for compiled templates ([ff68e15](https://github.com/openfoodfacts/openfoodfacts-server/commit/ff68e15309d5ca27d4c52ca76505aec37c3d6244))
* use PerlPostConfigRequire instead of PerlRequire ([cbecadc](https://github.com/openfoodfacts/openfoodfacts-server/commit/cbecadc79ad3a7684f18b6a3727f0b711f139f3d))
* use PRODUCT_OPENER_DOMAIN for MINION_QUEUES ([2db40ab](https://github.com/openfoodfacts/openfoodfacts-server/commit/2db40abc8785f1d6ed56a2dcea9026844c62b2d7))
* use PRODUCT_OPENER_DOMAIN for MINION_QUEUES ([d126bb2](https://github.com/openfoodfacts/openfoodfacts-server/commit/d126bb242ca91d52dff434b9dce341d0e7f6f594))
* use relative path to find tests expected results ([27392a7](https://github.com/openfoodfacts/openfoodfacts-server/commit/27392a7f1e942202ea9af1f677430fe641224302))
* volume is podata not po_data ([99c09a7](https://github.com/openfoodfacts/openfoodfacts-server/commit/99c09a745ff6675d355f60d9e170b5c1edd11bad))
* volume is podata not po_data ([5b89f45](https://github.com/openfoodfacts/openfoodfacts-server/commit/5b89f458c0de5fe7a2c6b375eaf95ca20e8d925e))
