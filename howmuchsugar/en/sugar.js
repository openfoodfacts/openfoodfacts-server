/**
 * Combien de sucres ? / How much sugar?
 * Modern Responsive Interactive Game & Physics Engine
 * Powered by Open Food Facts (https://openfoodfacts.org)
 */
(function () {
  "use strict";

  // Detect language from HTML or hostname
  var defaultLang = "fr";
  try {
    var htmlLang = (document.documentElement.getAttribute("lang") || "").toLowerCase();
    var metaLang = (
      (document.querySelector('meta[name="language"]') &&
        document.querySelector('meta[name="language"]').getAttribute("content")) ||
      ""
    ).toLowerCase();
    if (
      htmlLang.indexOf("en") === 0 ||
      metaLang.indexOf("en") === 0 ||
      window.location.hostname.indexOf("howmuchsugar") !== -1 ||
      window.location.pathname.indexOf("howmuchsugar") !== -1
    ) {
      defaultLang = "en";
    }
  } catch (e) {}

  var I18N = {
    fr: {
      siteTitle: "Combien de sucres ?",
      tagline: "Devinez combien de morceaux de sucre se cachent dans vos aliments du quotidien !",
      modeQuiz: "Jeu (5 produits)",
      modeSearch: "Chercher / Tester",
      modeSandbox: "Bac à sable",
      catAll: "Tous",
      catDrinks: "Boissons",
      catSweet: "Biscuits & Goûter",
      catDairy: "Laitages & Desserts",
      catBreakfast: "Petit-déjeuner",
      catSavory: "Salé & Sauces",
      roundLabel: "Manche de 5 produits",
      productStep: "Produit",
      scoreLabel: "Score",
      pointsUnit: "pts",
      brandLabel: "Marque",
      quantityLabel: "Quantité",
      scalePackage: "Tout le produit",
      scale100g: "Pour 100 g / ml",
      questionPrompt: function (qty, name) {
        return (
          "À combien de petits morceaux de sucre (<strong>4 g</strong>) équivaut <strong>" +
          qty +
          "</strong> de <strong>" +
          name +
          "</strong> ?"
        );
      },
      cubesSingular: "petit morceau de sucre",
      cubesPlural: "petits morceaux de sucre",
      gramsEquiv: function (g, kcal) {
        return "≈ " + g + " g de sucre • " + kcal + " kcal";
      },
      btnValidate: "Valider ma réponse",
      btnNext: "Produit suivant",
      btnSeeResults: "Voir mon bilan (5/5)",
      btnReplay: "Rejouer une manche",
      btnShareProduct: "Défier un ami",
      btnShake: "Secouer",
      btnClear: "Vider",
      btnRain: "Pluie de sucres",
      btnPhoto: "Capturer",
      zoomHint: "Cliquer sur l'image pour agrandir",
      mouseHint: "Astuce : attrapez et lancez les morceaux de sucre avec la souris ou le doigt !",
      whoLine25: "Recommandation OMS idéale (25 g / jour)",
      whoLine50: "Limite max OMS (50 g / jour)",
      yourGuess: "Votre réponse",
      actualSugar: "Réalité",
      whiteCubesLegend: "Votre estimation (sucres blancs)",
      brownCubesLegend: "Sucre sous-estimé (sucres roux)",
      excessCubesLegend: "Sucre surestimé",
      revealTitlePerfect: "Pile dans le mille !",
      revealTitleGreat: "Très bonne estimation !",
      revealTitleGood: "Pas mal du tout !",
      revealTitleUnder: "Attention aux sucres cachés !",
      revealTitleOver: "Un peu surestimé !",
      revealText: function (qty, name, url, g, smallF, bigF) {
        return (
          "<strong>" +
          qty +
          '</strong> de <a href="' +
          url +
          '" target="_blank" rel="noopener">' +
          name +
          "</a> contient <strong>" +
          g +
          " g de sucre</strong>, soit l'équivalent de <strong>" +
          smallF +
          " petits morceaux</strong> (4 g) ou <strong>" +
          bigF +
          " grands morceaux</strong> (6 g)."
        );
      },
      whoComparison: function (pct) {
        return "Soit <strong>" + pct + " %</strong> de l'apport quotidien idéal recommandé par l'OMS (25 g).";
      },
      viewOnOFF: "Voir la fiche sur Open Food Facts ↗",
      summaryTitle: "Bilan de votre manche",
      summarySubtitle: function (score, max) {
        if (score >= 45) return "Expert absolu en nutrition ! Vous ne vous laissez pas piéger.";
        if (score >= 35) return "Très bel œil ! Vous connaissez bien les produits du quotidien.";
        if (score >= 25) return "Pas mal ! Mais certains sucres cachés vous ont surpris.";
        return "Les sucres cachés sont redoutables… Rejouez pour affûter votre œil !";
      },
      statExact: function (n) {
        return "Estimation exacte sur <strong>" + n + "</strong> " + (n > 1 ? "produits" : "produit") + ".";
      },
      statUnder: function (n, cubes, g) {
        return (
          "Sous-estimé sur <strong>" +
          n +
          "</strong> " +
          (n > 1 ? "produits" : "produit") +
          " (<strong>" +
          cubes +
          " morceaux</strong> soit <strong>" +
          g +
          " g</strong> de sucre caché non vus)."
        );
      },
      statOver: function (n, cubes) {
        return (
          "Surestimé sur <strong>" +
          n +
          "</strong> " +
          (n > 1 ? "produits" : "produit") +
          " (+" +
          cubes +
          " morceaux)."
        );
      },
      shareScoreBtn: "Partager mon score",
      copiedToast: "Lien ou résumé copié dans le presse-papiers !",
      searchPlaceholder: "Rechercher un produit ou code-barres (ex: Nutella, Coca, 3017620422003)…",
      searchBtn: "Rechercher",
      searchHint: "Testez un produit de votre placard grâce à la base Open Food Facts :",
      searchLoading: "Recherche dans Open Food Facts…",
      searchNoResults: "Aucun produit avec teneur en sucres trouvé. Essayez un autre terme.",
      playThisProduct: "Jouer ce produit",
      sandboxTitle: "Bac à sable physique",
      sandboxDesc:
        "Ajoutez autant de morceaux de sucre blancs ou roux que vous voulez, secouez le bocal et empilez-les avec votre souris ou votre doigt !",
      addWhite: "+ Sucre blanc",
      addBrown: "+ Sucre roux",
      soundOn: "Son activé",
      soundOff: "Son coupé",
      progressInit: "Évaluez la quantité de sucre de 5 produits pour découvrir votre score !"
    },
    en: {
      siteTitle: "How much sugar?",
      tagline: "Guess how many sugar cubes are hiding in your everyday food products!",
      modeQuiz: "Quiz (5 products)",
      modeSearch: "Search / Test",
      modeSandbox: "Sandbox",
      catAll: "All",
      catDrinks: "Drinks",
      catSweet: "Sweet Snacks",
      catDairy: "Dairy & Desserts",
      catBreakfast: "Breakfast",
      catSavory: "Savory & Sauces",
      roundLabel: "5-Product Round",
      productStep: "Product",
      scoreLabel: "Score",
      pointsUnit: "pts",
      brandLabel: "Brand",
      quantityLabel: "Quantity",
      scalePackage: "Whole package",
      scale100g: "Per 100 g / ml",
      questionPrompt: function (qty, name) {
        return (
          "How many small sugar cubes (<strong>4 g</strong>) are in <strong>" +
          qty +
          "</strong> of <strong>" +
          name +
          "</strong>?"
        );
      },
      cubesSingular: "small sugar cube",
      cubesPlural: "small sugar cubes",
      gramsEquiv: function (g, kcal) {
        return "≈ " + g + " g of sugar • " + kcal + " kcal";
      },
      btnValidate: "Check my answer",
      btnNext: "Next product",
      btnSeeResults: "See final score (5/5)",
      btnReplay: "Play another round",
      btnShareProduct: "Challenge a friend",
      btnShake: "Shake",
      btnClear: "Clear",
      btnRain: "Sugar rain",
      btnPhoto: "Snapshot",
      zoomHint: "Click image to zoom",
      mouseHint: "Tip: grab, stack, and fling sugar cubes with your mouse or finger!",
      whoLine25: "WHO ideal daily limit (25 g / day)",
      whoLine50: "WHO max daily limit (50 g / day)",
      yourGuess: "Your guess",
      actualSugar: "Actual",
      whiteCubesLegend: "Your guess (white cubes)",
      brownCubesLegend: "Underestimated sugar (brown cubes)",
      excessCubesLegend: "Overestimated sugar",
      revealTitlePerfect: "Spot on!",
      revealTitleGreat: "Great estimate!",
      revealTitleGood: "Nice job!",
      revealTitleUnder: "Watch out for hidden sugars!",
      revealTitleOver: "Slightly overestimated!",
      revealText: function (qty, name, url, g, smallF, bigF) {
        return (
          "<strong>" +
          qty +
          '</strong> of <a href="' +
          url +
          '" target="_blank" rel="noopener">' +
          name +
          "</a> contains <strong>" +
          g +
          " g of sugar</strong>, equivalent to <strong>" +
          smallF +
          " small cubes</strong> (4 g) or <strong>" +
          bigF +
          " large cubes</strong> (6 g)."
        );
      },
      whoComparison: function (pct) {
        return "That is <strong>" + pct + "%</strong> of the WHO recommended ideal daily intake (25 g).";
      },
      viewOnOFF: "View product on Open Food Facts ↗",
      summaryTitle: "Your Round Summary",
      summarySubtitle: function (score, max) {
        if (score >= 45) return "Nutrition master! Hidden sugars cannot fool you.";
        if (score >= 35) return "Sharp eye! You know your everyday foods well.";
        if (score >= 25) return "Good effort! A few hidden sugars caught you off guard.";
        return "Hidden sugars are tricky… Play again to sharpen your intuition!";
      },
      statExact: function (n) {
        return "Exact match on <strong>" + n + "</strong> " + (n > 1 ? "products" : "product") + ".";
      },
      statUnder: function (n, cubes, g) {
        return (
          "Underestimated on <strong>" +
          n +
          "</strong> " +
          (n > 1 ? "products" : "product") +
          " (missed <strong>" +
          cubes +
          " cubes</strong> / <strong>" +
          g +
          " g</strong> of hidden sugar)."
        );
      },
      statOver: function (n, cubes) {
        return (
          "Overestimated on <strong>" +
          n +
          "</strong> " +
          (n > 1 ? "products" : "product") +
          " (+" +
          cubes +
          " cubes)."
        );
      },
      shareScoreBtn: "Share my score",
      copiedToast: "Copied to clipboard!",
      searchPlaceholder: "Search any product or barcode (e.g. Nutella, Coke, 3017620422003)…",
      searchBtn: "Search",
      searchHint: "Test any food product from the Open Food Facts database:",
      searchLoading: "Searching Open Food Facts…",
      searchNoResults: "No product with sugar data found. Try another query.",
      playThisProduct: "Play this product",
      sandboxTitle: "Physics Sandbox",
      sandboxDesc:
        "Drop as many white or brown sugar cubes as you like, shake the jar, and stack them with your mouse or finger!",
      addWhite: "+ White cube",
      addBrown: "+ Brown cube",
      soundOn: "Sound on",
      soundOff: "Muted",
      progressInit: "Guess the sugar content of 5 products to get your score!"
    }
  };

  // Curated iconic products from Open Food Facts
  var CURATED_PRODUCTS = [
    {
      code: "5449000000996",
      name_fr: "Coca-Cola Original (Canette)",
      name_en: "Coca-Cola Original (Can)",
      brands: "Coca-Cola",
      quantity: "330 ml",
      product_quantity: 330,
      unit: "ml",
      sugars_100g: 10.6,
      nutriscore: "e",
      cat: "drinks",
      emoji: "🥤",
      img: "https://images.openfoodfacts.org/images/products/544/900/000/0996/front_fr.724.400.jpg"
    },
    {
      code: "3017620422003",
      name_fr: "Nutella Pâte à tartiner (Pot)",
      name_en: "Nutella Hazelnut Spread (Jar)",
      brands: "Ferrero, Nutella",
      quantity: "400 g",
      product_quantity: 400,
      unit: "g",
      sugars_100g: 56.3,
      nutriscore: "e",
      cat: "breakfast",
      emoji: "🍫",
      img: "https://images.openfoodfacts.org/images/products/301/762/042/2003/front_fr.597.400.jpg"
    },
    {
      code: "3017620422003_portion",
      real_code: "3017620422003",
      name_fr: "Nutella (2 cuillères à soupe)",
      name_en: "Nutella (2 tablespoons)",
      brands: "Ferrero, Nutella",
      quantity: "30 g",
      product_quantity: 30,
      unit: "g",
      sugars_100g: 56.3,
      nutriscore: "e",
      cat: "breakfast",
      emoji: "🥄",
      img: "https://images.openfoodfacts.org/images/products/301/762/042/2003/front_fr.597.400.jpg"
    },
    {
      code: "3168930010265",
      name_fr: "Pur Jus d'Orange Sans Pulpe (Bouteille)",
      name_en: "100% Pure Orange Juice (Bottle)",
      brands: "Tropicana",
      quantity: "1 L",
      product_quantity: 1000,
      unit: "ml",
      sugars_100g: 10.0,
      nutriscore: "c",
      cat: "drinks",
      emoji: "🍊",
      img: "https://images.openfoodfacts.org/images/products/316/893/001/0265/front_fr.165.400.jpg"
    },
    {
      code: "3124480191182",
      name_fr: "Oasis Tropical (Canette)",
      name_en: "Oasis Tropical Fruit Drink (Can)",
      brands: "Oasis",
      quantity: "330 ml",
      product_quantity: 330,
      unit: "ml",
      sugars_100g: 7.9,
      nutriscore: "d",
      cat: "drinks",
      emoji: "🍹",
      img: "https://images.openfoodfacts.org/images/products/312/448/019/1182/front_fr.105.400.jpg"
    },
    {
      code: "8715700407760",
      name_fr: "Tomato Ketchup (Flacon)",
      name_en: "Tomato Ketchup (Squeeze Bottle)",
      brands: "Heinz",
      quantity: "700 g",
      product_quantity: 700,
      unit: "g",
      sugars_100g: 22.8,
      nutriscore: "d",
      cat: "savory",
      emoji: "🍅",
      img: "https://images.openfoodfacts.org/images/products/871/570/040/7760/front_fr.124.400.jpg"
    },
    {
      code: "9002490100070",
      name_fr: "Red Bull Energy Drink (Canette)",
      name_en: "Red Bull Energy Drink (Can)",
      brands: "Red Bull",
      quantity: "250 ml",
      product_quantity: 250,
      unit: "ml",
      sugars_100g: 11.0,
      nutriscore: "e",
      cat: "drinks",
      emoji: "⚡",
      img: "https://images.openfoodfacts.org/images/products/900/249/010/0070/front_fr.208.400.jpg"
    },
    {
      code: "7622210449283",
      name_fr: "Biscuits Prince Chocolat (Paquet)",
      name_en: "Prince Chocolate Biscuits (Pack)",
      brands: "LU",
      quantity: "300 g",
      product_quantity: 300,
      unit: "g",
      sugars_100g: 32.0,
      nutriscore: "d",
      cat: "sweet",
      emoji: "🍪",
      img: "https://images.openfoodfacts.org/images/products/762/221/044/9283/front_fr.544.400.jpg"
    },
    {
      code: "3046920022651",
      name_fr: "Chocolat Noir Excellence 70% Cacao",
      name_en: "Excellence 70% Dark Chocolate Bar",
      brands: "Lindt",
      quantity: "100 g",
      product_quantity: 100,
      unit: "g",
      sugars_100g: 30.0,
      nutriscore: "e",
      cat: "sweet",
      emoji: "🍫",
      img: "https://images.openfoodfacts.org/images/products/304/692/002/2651/front_fr.300.400.jpg"
    },
    {
      code: "3045140105502",
      name_fr: "Chocolat au Lait du Pays Alpin",
      name_en: "Alpine Milk Chocolate Bar",
      brands: "Milka",
      quantity: "100 g",
      product_quantity: 100,
      unit: "g",
      sugars_100g: 58.0,
      nutriscore: "e",
      cat: "sweet",
      emoji: "🐄",
      img: "https://images.openfoodfacts.org/images/products/304/514/010/5502/front_fr.272.400.jpg"
    },
    {
      code: "3033490004743",
      name_fr: "Danette Crème Dessert Chocolat (4 pots)",
      name_en: "Danette Chocolate Pudding (4 cups)",
      brands: "Danone, Danette",
      quantity: "500 g",
      product_quantity: 500,
      unit: "g",
      sugars_100g: 15.6,
      nutriscore: "c",
      cat: "dairy",
      emoji: "🍮",
      img: "https://images.openfoodfacts.org/images/products/303/349/000/4743/front_fr.193.400.jpg"
    },
    {
      code: "3329770077007",
      name_fr: "Panier de Yoplait Yaourt aux Fruits (2 pots)",
      name_en: "Yoplait Fruit Yogurt (2 cups)",
      brands: "Yoplait",
      quantity: "250 g",
      product_quantity: 250,
      unit: "g",
      sugars_100g: 12.9,
      nutriscore: "c",
      cat: "dairy",
      emoji: "🍓",
      img: "https://images.openfoodfacts.org/images/products/332/977/007/7007/front_fr.102.400.jpg"
    },
    {
      code: "7613034626844",
      name_fr: "Céréales Chocapic (Paquet)",
      name_en: "Chocapic Chocolate Cereals (Box)",
      brands: "Nestlé",
      quantity: "430 g",
      product_quantity: 430,
      unit: "g",
      sugars_100g: 22.4,
      nutriscore: "a",
      cat: "breakfast",
      emoji: "🥣",
      img: "https://images.openfoodfacts.org/images/products/761/303/462/6844/front_fr.326.400.jpg"
    },
    {
      code: "8000500037560",
      name_fr: "Kinder Bueno (Sachet de 2 barres)",
      name_en: "Kinder Bueno (2 bars pack)",
      brands: "Ferrero, Kinder",
      quantity: "43 g",
      product_quantity: 43,
      unit: "g",
      sugars_100g: 41.2,
      nutriscore: "e",
      cat: "sweet",
      emoji: "🍬",
      img: "https://images.openfoodfacts.org/images/products/800/050/003/7560/front_fr.281.400.jpg"
    },
    {
      code: "3228857000166",
      name_fr: "Pain de Mie 100% Mie Nature",
      name_en: "harrys Soft Sliced Sandwich Bread",
      brands: "Harrys",
      quantity: "500 g",
      product_quantity: 500,
      unit: "g",
      sugars_100g: 7.9,
      nutriscore: "a",
      cat: "breakfast",
      emoji: "🍞",
      img: "https://images.openfoodfacts.org/images/products/322/885/700/0166/front_fr.176.400.jpg"
    },
    {
      code: "5060335635266",
      name_fr: "Monster Energy (Grande Canette)",
      name_en: "Monster Energy Drink (Large Can)",
      brands: "Monster",
      quantity: "500 ml",
      product_quantity: 500,
      unit: "ml",
      sugars_100g: 11.0,
      nutriscore: "e",
      cat: "drinks",
      emoji: "👹",
      img: "https://images.openfoodfacts.org/images/products/506/033/563/5266/front_fr.89.400.jpg"
    },
    {
      code: "3105320005509",
      name_fr: "Compote Pomme Nature (4 pots)",
      name_en: "Apple Compote (4 cups)",
      brands: "Andros",
      quantity: "400 g",
      product_quantity: 400,
      unit: "g",
      sugars_100g: 16.0,
      nutriscore: "b",
      cat: "dairy",
      emoji: "🍎",
      img: "https://images.openfoodfacts.org/images/products/310/532/000/5509/front_fr.55.400.jpg"
    },
    {
      code: "3103220025207",
      name_fr: "Bonbons Dragibus (Sachet)",
      name_en: "Haribo Dragibus Jelly Beans (Bag)",
      brands: "Haribo",
      quantity: "120 g",
      product_quantity: 120,
      unit: "g",
      sugars_100g: 69.0,
      nutriscore: "d",
      cat: "sweet",
      emoji: "🍬",
      img: "https://images.openfoodfacts.org/images/products/310/322/002/5207/front_fr.44.400.jpg"
    },
    {
      code: "7622300336738",
      name_fr: "Biscuits Oreo Original (Rouleau)",
      name_en: "Oreo Original Cookies (Roll)",
      brands: "Oreo, Mondelez",
      quantity: "154 g",
      product_quantity: 154,
      unit: "g",
      sugars_100g: 38.0,
      nutriscore: "e",
      cat: "sweet",
      emoji: "🍪",
      img: "https://images.openfoodfacts.org/images/products/762/230/033/6738/front_fr.301.400.jpg"
    },
    {
      code: "4000177605004",
      name_fr: "Capri-Sun Multivitamin (Poche)",
      name_en: "Capri-Sun Multivitamin (Pouch)",
      brands: "Capri-Sun",
      quantity: "200 ml",
      product_quantity: 200,
      unit: "ml",
      sugars_100g: 8.6,
      nutriscore: "d",
      cat: "drinks",
      emoji: "🧃",
      img: "https://images.openfoodfacts.org/images/products/400/017/760/5004/front_fr.110.400.jpg"
    },
    {
      code: "3228021170020",
      name_fr: "Lipton Ice Tea Pêche (Bouteille)",
      name_en: "Lipton Peach Iced Tea (Bottle)",
      brands: "Lipton",
      quantity: "500 ml",
      product_quantity: 500,
      unit: "ml",
      sugars_100g: 4.5,
      nutriscore: "c",
      cat: "drinks",
      emoji: "🍑",
      img: "https://images.openfoodfacts.org/images/products/322/802/117/0020/front_fr.65.400.jpg"
    },
    {
      code: "3083681095302",
      name_fr: "Petits Pois & Carottes (Boîte)",
      name_en: "Canned Peas & Young Carrots",
      brands: "Cassegrain",
      quantity: "265 g",
      product_quantity: 265,
      unit: "g",
      sugars_100g: 5.7,
      nutriscore: "a",
      cat: "savory",
      emoji: "🥕",
      img: "https://images.openfoodfacts.org/images/products/308/368/109/5302/front_fr.112.400.jpg"
    },
    {
      code: "8712100731822",
      name_fr: "Sauce Barbecue Classique (Flacon)",
      name_en: "Classic Smokey BBQ Sauce (Bottle)",
      brands: "Amora",
      quantity: "286 g",
      product_quantity: 286,
      unit: "g",
      sugars_100g: 27.0,
      nutriscore: "d",
      cat: "savory",
      emoji: "🍖",
      img: "https://images.openfoodfacts.org/images/products/871/210/073/1822/front_fr.54.400.jpg"
    },
    {
      code: "3029330003533",
      name_fr: "Pain de Mie Complet Sans Sucres Ajoutés",
      name_en: "Wholewheat Sliced Bread",
      brands: "Jacquet",
      quantity: "550 g",
      product_quantity: 550,
      unit: "g",
      sugars_100g: 4.2,
      nutriscore: "a",
      cat: "breakfast",
      emoji: "🍞",
      img: "https://images.openfoodfacts.org/images/products/302/933/000/3533/front_fr.229.400.jpg"
    }
  ];

  // State
  var state = {
    lang: defaultLang,
    mode: "quiz", // 'quiz' | 'search' | 'sandbox'
    category: "all",
    scaleMode: "package", // 'package' | '100g'
    soundEnabled: true,
    tries: 5,
    roundIndex: 0, // 0..4
    roundProducts: [],
    roundHistory: [], // { product, guess, actualSmall, actualSmallF, actualGrams, points }
    currentProduct: null,
    guessCubes: 0,
    revealed: false,
    usedCodes: {}
  };

  // Sound synthesizer (Web Audio API)
  var audioCtx = null;
  function playTone(freq, type, duration, vol) {
    if (!state.soundEnabled) return;
    try {
      if (!audioCtx) {
        var AudioContext = window.AudioContext || window.webkitAudioContext;
        if (AudioContext) audioCtx = new AudioContext();
      }
      if (!audioCtx) return;
      if (audioCtx.state === "suspended") audioCtx.resume();
      var osc = audioCtx.createOscillator();
      var gain = audioCtx.createGain();
      osc.type = type || "sine";
      osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
      gain.gain.setValueAtTime(vol || 0.06, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + (duration || 0.08));
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + (duration || 0.08));
    } catch (e) {}
  }

  function playCubeSound(count) {
    var base = 420 + Math.min(count * 12, 500) + (Math.random() * 40 - 20);
    playTone(base, "triangle", 0.06, 0.05);
  }

  function playRevealSound(points) {
    if (points >= 8) {
      playTone(523.25, "sine", 0.12, 0.08);
      setTimeout(function () {
        playTone(659.25, "sine", 0.14, 0.08);
      }, 100);
      setTimeout(function () {
        playTone(783.99, "sine", 0.25, 0.09);
      }, 210);
    } else {
      playTone(392.0, "triangle", 0.14, 0.07);
      setTimeout(function () {
        playTone(329.63, "triangle", 0.22, 0.07);
      }, 130);
    }
  }

  // Helper to compute sugar metrics for a product & scaleMode
  function computeMetrics(prod, scaleMode) {
    var qtyGrams = prod.product_quantity || 100;
    var qtyLabel = prod.quantity || "100 g";
    if (scaleMode === "100g") {
      qtyGrams = 100;
      qtyLabel = prod.unit === "ml" ? "100 ml" : "100 g";
    }
    var sugars100 = typeof prod.sugars_100g === "number" ? prod.sugars_100g : 10;
    var totalSugarG = (qtyGrams * sugars100) / 100;
    // Cap at 75 cubes max for the game jar if package is huge
    var rawCubes = totalSugarG / 4;
    var smallRounded = Math.max(0, Math.round(rawCubes));
    var smallF = Math.round(rawCubes * 10) / 10;
    var bigF = Math.round((totalSugarG / 6) * 10) / 10;
    var gramsRounded = Math.round(totalSugarG * 10) / 10;
    var realCode = prod.real_code || prod.code || "";
    var offDomain = state.lang === "fr" ? "https://fr.openfoodfacts.org" : "https://world.openfoodfacts.org";
    var url = prod.url || (realCode ? offDomain + "/product/" + realCode : offDomain);
    var name = state.lang === "fr" ? prod.name_fr || prod.name_en || prod.name : prod.name_en || prod.name_fr || prod.name;
    return {
      name: name,
      brands: prod.brands || "Open Food Facts",
      qtyLabel: qtyLabel,
      qtyGrams: qtyGrams,
      sugarsG: gramsRounded,
      small: Math.min(75, smallRounded),
      rawSmall: smallRounded,
      smallF: smallF,
      bigF: bigF,
      url: url,
      nutriscore: (prod.nutriscore || "").toLowerCase(),
      emoji: prod.emoji || "🍽️",
      img: prod.img || ""
    };
  }

  // Scoring formula (original Combien de sucres formula)
  function computePoints(guess, actualSmallF) {
    if (actualSmallF <= 0) return guess === 0 ? 10 : Math.max(0, 10 - guess);
    var diff = Math.abs(guess - actualSmallF);
    var relPoints = 10 - Math.floor((diff / actualSmallF) * 10);
    var absPoints = 10 - Math.floor(diff);
    var pts = Math.max(relPoints, absPoints);
    return Math.max(0, Math.min(10, pts));
  }

  // Generate SVG fallback data URI for product photo
  function makeFallbackSvg(emoji, title) {
    var safeEmoji = emoji || "🍽️";
    var svg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240" viewBox="0 0 240 240">' +
      '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">' +
      '<stop offset="0%" stop-color="#eff6ff"/><stop offset="100%" stop-color="#dbeafe"/></linearGradient></defs>' +
      '<rect width="240" height="240" rx="20" fill="url(#g)"/>' +
      '<circle cx="120" cy="110" r="64" fill="#ffffff" opacity="0.85"/>' +
      '<text x="120" y="132" font-size="68" text-anchor="middle">' +
      safeEmoji +
      "</text>" +
      '<text x="120" y="210" font-family="sans-serif" font-size="13" fill="#1e40af" font-weight="bold" text-anchor="middle">Open Food Facts</text>' +
      "</svg>";
    return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
  }

  // =========================================================================
  // 2D PHYSICS + RETINA CANVAS RENDERER
  // =========================================================================
  var STAGE_W = 450;
  var STAGE_H = 650;
  var METER = 100; // 100px = 1m in Box2D

  var physics = {
    world: null,
    useBox2D: false,
    bodies: [], // { body, type: 'white'|'brown'|'excess', x, y, vx, vy, angle, va, w, h, alpha, scale }
    floats: [], // floating text animations
    particles: [],
    mouseX: undefined,
    mouseY: undefined,
    isPointerDown: false,
    mouseJoint: null,
    grabbedItem: null,
    canvas: null,
    ctx: null,
    whiteImg: null,
    brownImg: null
  };

  function initSprites() {
    var wImg = new Image();
    wImg.src = "sucre-blanc.120x104.png";
    physics.whiteImg = wImg;

    var bImg = new Image();
    bImg.src = "sucre-roux.60x52.png";
    physics.brownImg = bImg;
  }

  function initPhysicsWorld() {
    physics.bodies = [];
    physics.floats = [];
    physics.particles = [];
    physics.mouseJoint = null;
    physics.grabbedItem = null;

    if (typeof Box2D !== "undefined") {
      physics.useBox2D = true;
      var b2Vec2 = Box2D.Common.Math.b2Vec2;
      var b2BodyDef = Box2D.Dynamics.b2BodyDef;
      var b2Body = Box2D.Dynamics.b2Body;
      var b2FixtureDef = Box2D.Dynamics.b2FixtureDef;
      var b2World = Box2D.Dynamics.b2World;
      var b2PolygonShape = Box2D.Collision.Shapes.b2PolygonShape;

      physics.world = new b2World(new b2Vec2(0, 26), true);

      var fixDef = new b2FixtureDef();
      fixDef.shape = new b2PolygonShape();
      fixDef.friction = 0.5;
      fixDef.restitution = 0.15;

      var bodyDef = new b2BodyDef();
      bodyDef.type = b2Body.b2_staticBody;

      // Ground (at bottom of jar: STAGE_H - 18)
      fixDef.shape.SetAsBox(10, 1);
      bodyDef.position.Set(STAGE_W / 2 / METER, (STAGE_H - 14) / METER + 1);
      physics.world.CreateBody(bodyDef).CreateFixture(fixDef);

      // Left wall
      fixDef.shape.SetAsBox(1, 20);
      bodyDef.position.Set(14 / METER - 1, STAGE_H / 2 / METER);
      physics.world.CreateBody(bodyDef).CreateFixture(fixDef);

      // Right wall
      bodyDef.position.Set((STAGE_W - 14) / METER + 1, STAGE_H / 2 / METER);
      physics.world.CreateBody(bodyDef).CreateFixture(fixDef);
    } else {
      physics.useBox2D = false;
    }
  }

  function spawnCube(type, indexOffset) {
    var cw = 54;
    var ch = 46;
    var startX = STAGE_W * 0.25 + Math.random() * (STAGE_W * 0.5);
    var startY = -30 - (indexOffset || 0) * 52 - Math.random() * 20;
    var startAngle = (Math.random() - 0.5) * 0.9;

    var item = {
      type: type || "white", // 'white' | 'brown'
      x: startX,
      y: startY,
      vx: (Math.random() - 0.5) * 2,
      vy: 0,
      angle: startAngle,
      va: (Math.random() - 0.5) * 0.05,
      w: cw,
      h: ch,
      alpha: 1,
      body: null
    };

    if (physics.useBox2D && physics.world) {
      var b2BodyDef = Box2D.Dynamics.b2BodyDef;
      var b2Body = Box2D.Dynamics.b2Body;
      var b2FixtureDef = Box2D.Dynamics.b2FixtureDef;
      var b2PolygonShape = Box2D.Collision.Shapes.b2PolygonShape;

      var fixDef = new b2FixtureDef();
      fixDef.shape = new b2PolygonShape();
      fixDef.shape.SetAsBox((cw * 0.47) / METER, (ch * 0.47) / METER);
      fixDef.density = 1.0;
      fixDef.friction = 0.55;
      fixDef.restitution = 0.12;

      var bodyDef = new b2BodyDef();
      bodyDef.type = b2Body.b2_dynamicBody;
      bodyDef.position.Set(startX / METER, startY / METER);
      bodyDef.angle = startAngle;
      bodyDef.linearDamping = 0.1;
      bodyDef.angularDamping = 0.15;

      var body = physics.world.CreateBody(bodyDef);
      body.CreateFixture(fixDef);
      item.body = body;
    }

    physics.bodies.push(item);
  }

  function removeOneCube() {
    if (physics.bodies.length === 0) return;
    var item = physics.bodies.pop();
    if (item) {
      // Spawn pop particles
      for (var p = 0; p < 7; p++) {
        physics.particles.push({
          x: item.x,
          y: Math.max(40, item.y),
          vx: (Math.random() - 0.5) * 6,
          vy: -Math.random() * 5 - 1,
          size: 4 + Math.random() * 5,
          alpha: 1,
          color: item.type === "brown" ? "#d97706" : "#ffffff"
        });
      }
      if (item.body && physics.world) {
        if (physics.mouseJoint && physics.mouseJoint.GetBodyB() === item.body) {
          physics.world.DestroyJoint(physics.mouseJoint);
          physics.mouseJoint = null;
        }
        physics.world.DestroyBody(item.body);
      }
    }
  }

  function addFloatingLabel(text, color) {
    physics.floats.push({
      text: text,
      x: STAGE_W / 2 + (Math.random() * 60 - 30),
      y: 110,
      vy: -1.6,
      alpha: 1.0,
      color: color || "#ffffff"
    });
  }

  function shakeCubes() {
    playCubeSound(10);
    for (var i = 0; i < physics.bodies.length; i++) {
      var b = physics.bodies[i];
      if (b.body && physics.useBox2D) {
        var b2Vec2 = Box2D.Common.Math.b2Vec2;
        b.body.SetAwake(true);
        b.body.ApplyImpulse(
          new b2Vec2((Math.random() - 0.5) * 4, -Math.random() * 6 - 3),
          b.body.GetWorldCenter()
        );
        b.body.SetAngularVelocity((Math.random() - 0.5) * 8);
      } else {
        b.vy = -8 - Math.random() * 6;
        b.vx = (Math.random() - 0.5) * 10;
      }
    }
  }

  function stepPhysics() {
    if (physics.useBox2D && physics.world) {
      var b2Vec2 = Box2D.Common.Math.b2Vec2;
      var b2AABB = Box2D.Collision.b2AABB;
      var b2Body = Box2D.Dynamics.b2Body;
      var b2MouseJointDef = Box2D.Dynamics.Joints.b2MouseJointDef;

      if (physics.isPointerDown && !physics.mouseJoint && physics.mouseX !== undefined) {
        var mousePVec = new b2Vec2(physics.mouseX, physics.mouseY);
        var aabb = new b2AABB();
        aabb.lowerBound.Set(physics.mouseX - 0.02, physics.mouseY - 0.02);
        aabb.upperBound.Set(physics.mouseX + 0.02, physics.mouseY + 0.02);
        var selectedBody = null;
        physics.world.QueryAABB(function (fixture) {
          if (fixture.GetBody().GetType() !== b2Body.b2_staticBody) {
            if (fixture.GetShape().TestPoint(fixture.GetBody().GetTransform(), mousePVec)) {
              selectedBody = fixture.GetBody();
              return false;
            }
          }
          return true;
        }, aabb);

        if (selectedBody) {
          var md = new b2MouseJointDef();
          md.bodyA = physics.world.GetGroundBody();
          md.bodyB = selectedBody;
          md.target.Set(physics.mouseX, physics.mouseY);
          md.collideConnected = true;
          md.maxForce = 350.0 * selectedBody.GetMass();
          physics.mouseJoint = physics.world.CreateJoint(md);
          selectedBody.SetAwake(true);
        }
      }

      if (physics.mouseJoint) {
        if (physics.isPointerDown && physics.mouseX !== undefined) {
          physics.mouseJoint.SetTarget(new b2Vec2(physics.mouseX, physics.mouseY));
        } else {
          physics.world.DestroyJoint(physics.mouseJoint);
          physics.mouseJoint = null;
        }
      }

      physics.world.Step(1 / 60, 8, 3);
      physics.world.ClearForces();

      for (var i = 0; i < physics.bodies.length; i++) {
        var item = physics.bodies[i];
        if (item.body) {
          var pos = item.body.GetPosition();
          item.x = pos.x * METER;
          item.y = pos.y * METER;
          item.angle = item.body.GetAngle();
        }
      }
    } else {
      // Fallback simple impulse physics
      var floorY = STAGE_H - 38;
      for (var j = 0; j < physics.bodies.length; j++) {
        var c = physics.bodies[j];
        c.vy += 0.65;
        c.x += c.vx;
        c.y += c.vy;
        c.angle += c.va;
        if (c.x < 42) {
          c.x = 42;
          c.vx *= -0.4;
        }
        if (c.x > STAGE_W - 42) {
          c.x = STAGE_W - 42;
          c.vx *= -0.4;
        }
        if (c.y > floorY) {
          c.y = floorY;
          c.vy *= -0.2;
          c.vx *= 0.8;
          c.va *= 0.7;
        }
      }
    }

    // Update particles
    for (var p = physics.particles.length - 1; p >= 0; p--) {
      var pt = physics.particles[p];
      pt.x += pt.vx;
      pt.y += pt.vy;
      pt.vy += 0.28;
      pt.alpha -= 0.035;
      if (pt.alpha <= 0) physics.particles.splice(p, 1);
    }

    // Update floating labels
    for (var f = physics.floats.length - 1; f >= 0; f--) {
      var fl = physics.floats[f];
      fl.y += fl.vy;
      fl.alpha -= 0.022;
      if (fl.alpha <= 0) physics.floats.splice(f, 1);
    }
  }

  function drawProceduralCube(ctx, w, h, type) {
    var r = 7;
    var hw = w / 2;
    var hh = h / 2;

    ctx.beginPath();
    ctx.moveTo(-hw + r, -hh);
    ctx.lineTo(hw - r, -hh);
    ctx.quadraticCurveTo(hw, -hh, hw, -hh + r);
    ctx.lineTo(hw, hh - r);
    ctx.quadraticCurveTo(hw, hh, hw - r, hh);
    ctx.lineTo(-hw + r, hh);
    ctx.quadraticCurveTo(-hw, hh, -hw, hh - r);
    ctx.lineTo(-hw, -hh + r);
    ctx.quadraticCurveTo(-hw, -hh, -hw + r, -hh);
    ctx.closePath();

    if (type === "brown") {
      var gradB = ctx.createLinearGradient(-hw, -hh, hw, hh);
      gradB.addColorStop(0, "#f59e0b");
      gradB.addColorStop(0.5, "#d97706");
      gradB.addColorStop(1, "#92400e");
      ctx.fillStyle = gradB;
      ctx.fill();
      ctx.lineWidth = 2;
      ctx.strokeStyle = "#fef3c7";
      ctx.stroke();
    } else {
      var gradW = ctx.createLinearGradient(-hw, -hh, hw, hh);
      gradW.addColorStop(0, "#ffffff");
      gradW.addColorStop(0.65, "#f1f5f9");
      gradW.addColorStop(1, "#cbd5e1");
      ctx.fillStyle = gradW;
      ctx.fill();
      ctx.lineWidth = 1.5;
      ctx.strokeStyle = "#94a3b8";
      ctx.stroke();
    }

    // Inner crystal highlight
    ctx.fillStyle = type === "brown" ? "rgba(255,251,235,0.28)" : "rgba(255,255,255,0.75)";
    ctx.fillRect(-hw + 6, -hh + 5, w - 16, 6);
  }

  function renderStage() {
    var canvas = physics.canvas;
    var ctx = physics.ctx;
    if (!canvas || !ctx) return;

    var dpr = window.devicePixelRatio || 1;
    var targetW = STAGE_W * dpr;
    var targetH = STAGE_H * dpr;
    if (canvas.width !== targetW || canvas.height !== targetH) {
      canvas.width = targetW;
      canvas.height = targetH;
    }

    ctx.save();
    ctx.scale(dpr, dpr);

    // Sky / Glass Jar Background Gradient
    var bgGrad = ctx.createLinearGradient(0, 0, 0, STAGE_H);
    bgGrad.addColorStop(0, "#1e3a8a");
    bgGrad.addColorStop(0.5, "#1d4ed8");
    bgGrad.addColorStop(1, "#172554");
    ctx.fillStyle = bgGrad;
    ctx.fillRect(0, 0, STAGE_W, STAGE_H);

    // Subtle radial glow
    var radGrad = ctx.createRadialGradient(STAGE_W / 2, STAGE_H * 0.35, 30, STAGE_W / 2, STAGE_H * 0.5, 320);
    radGrad.addColorStop(0, "rgba(96, 165, 250, 0.22)");
    radGrad.addColorStop(1, "rgba(15, 23, 42, 0)");
    ctx.fillStyle = radGrad;
    ctx.fillRect(0, 0, STAGE_W, STAGE_H);

    // Glass jar walls & base
    ctx.strokeStyle = "rgba(191, 219, 254, 0.35)";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(14, 16);
    ctx.lineTo(14, STAGE_H - 28);
    ctx.quadraticCurveTo(14, STAGE_H - 14, 28, STAGE_H - 14);
    ctx.lineTo(STAGE_W - 28, STAGE_H - 14);
    ctx.quadraticCurveTo(STAGE_W - 14, STAGE_H - 14, STAGE_W - 14, STAGE_H - 28);
    ctx.lineTo(STAGE_W - 14, 16);
    ctx.stroke();

    // WHO Reference Lines (6 cubes ≈ 1 row, 12.5 cubes ≈ 2 rows)
    var t = I18N[state.lang];
    var y25g = STAGE_H - 82;
    var y50g = STAGE_H - 150;

    ctx.save();
    ctx.setLineDash([5, 5]);
    // 25g line
    ctx.strokeStyle = "rgba(134, 239, 172, 0.45)";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(20, y25g);
    ctx.lineTo(STAGE_W - 20, y25g);
    ctx.stroke();

    ctx.font = "600 11px Inter, system-ui, sans-serif";
    ctx.fillStyle = "rgba(167, 243, 208, 0.8)";
    ctx.textAlign = "right";
    ctx.fillText("OMS 25g (~6 morceaux)", STAGE_W - 24, y25g - 5);

    // 50g line
    ctx.strokeStyle = "rgba(253, 186, 116, 0.4)";
    ctx.beginPath();
    ctx.moveTo(20, y50g);
    ctx.lineTo(STAGE_W - 20, y50g);
    ctx.stroke();
    ctx.fillStyle = "rgba(254, 215, 170, 0.75)";
    ctx.fillText("Max 50g (~12 morceaux)", STAGE_W - 24, y50g - 5);
    ctx.restore();

    // Draw sugar cubes
    var whiteCount = 0;
    var brownCount = 0;
    for (var i = 0; i < physics.bodies.length; i++) {
      var item = physics.bodies[i];
      if (item.type === "brown") brownCount++;
      else whiteCount++;

      ctx.save();
      ctx.translate(item.x, item.y);
      ctx.rotate(item.angle);

      var img = item.type === "brown" ? physics.brownImg : physics.whiteImg;
      if (img && img.complete && img.naturalWidth > 0) {
        ctx.drawImage(img, -item.w / 2 - 3, -item.h / 2 - 3, item.w + 6, item.h + 6);
      } else {
        drawProceduralCube(ctx, item.w, item.h, item.type);
      }
      ctx.restore();
    }

    // Draw particles
    for (var p = 0; p < physics.particles.length; p++) {
      var pt = physics.particles[p];
      ctx.save();
      ctx.globalAlpha = Math.max(0, pt.alpha);
      ctx.fillStyle = pt.color;
      ctx.fillRect(pt.x - pt.size / 2, pt.y - pt.size / 2, pt.size, pt.size);
      ctx.restore();
    }

    // Draw floating labels
    for (var f = 0; f < physics.floats.length; f++) {
      var fl = physics.floats[f];
      ctx.save();
      ctx.globalAlpha = Math.max(0, fl.alpha);
      ctx.font = "bold 24px Inter, system-ui, sans-serif";
      ctx.fillStyle = fl.color;
      ctx.textAlign = "center";
      ctx.shadowColor = "rgba(0,0,0,0.4)";
      ctx.shadowBlur = 6;
      ctx.fillText(fl.text, fl.x, fl.y);
      ctx.restore();
    }

    // Top HUD inside Jar
    var totalCubes = physics.bodies.length;
    var totalGrams = totalCubes * 4;
    ctx.save();
    ctx.fillStyle = "rgba(15, 23, 42, 0.55)";
    ctx.beginPath();
    var pillW = 280;
    var pillX = (STAGE_W - pillW) / 2;
    ctx.roundRect ? ctx.roundRect(pillX, 18, pillW, 48, 24) : ctx.rect(pillX, 18, pillW, 48);
    ctx.fill();

    ctx.font = "bold 20px Inter, system-ui, sans-serif";
    ctx.fillStyle = "#ffffff";
    ctx.textAlign = "center";
    var cubeWord = totalCubes <= 1 ? t.cubesSingular : t.cubesPlural;
    ctx.fillText(totalCubes + " " + cubeWord, STAGE_W / 2, 42);

    ctx.font = "500 12px Inter, system-ui, sans-serif";
    ctx.fillStyle = "#93c5fd";
    var subText = "= " + totalGrams + " g de sucre";
    if (brownCount > 0) {
      subText = whiteCount + " blancs + " + brownCount + " roux (cachés) = " + totalGrams + " g";
    }
    ctx.fillText(subText, STAGE_W / 2, 59);
    ctx.restore();

    ctx.restore();
  }

  function animationLoop() {
    stepPhysics();
    renderStage();
    window.requestAnimationFrame(animationLoop);
  }

  // =========================================================================
  // GAME LOGIC & UI CONTROLLER
  // =========================================================================
  function setCubeCount(targetCount, cubeType) {
    targetCount = Math.max(0, Math.min(75, Math.round(targetCount)));
    var current = physics.bodies.length;
    var diff = targetCount - current;
    if (diff > 0) {
      for (var i = 0; i < diff; i++) {
        spawnCube(cubeType || "white", i);
      }
      playCubeSound(targetCount);
      addFloatingLabel("+" + diff, cubeType === "brown" ? "#fbbf24" : "#ffffff");
    } else if (diff < 0) {
      for (var j = 0; j < -diff; j++) {
        removeOneCube();
      }
      playCubeSound(targetCount);
      addFloatingLabel(String(diff), "#fca5a5");
    }
    state.guessCubes = physics.bodies.length;
    updateCounterUI();
  }

  function updateCounterUI() {
    var t = I18N[state.lang];
    var count = state.revealed ? state.guessCubes : physics.bodies.length;
    var grams = count * 4;
    var kcal = grams * 4;

    var countEl = document.getElementById("cds-cube-number");
    var wordEl = document.getElementById("cds-cube-word");
    var gramsEl = document.getElementById("cds-grams-equiv");
    var sliderEl = document.getElementById("cds-slider");
    var legacyCubes = document.getElementById("cubes");

    if (countEl) countEl.textContent = String(count);
    if (legacyCubes) legacyCubes.textContent = String(count);
    if (wordEl) wordEl.textContent = count <= 1 ? t.cubesSingular : t.cubesPlural;
    if (gramsEl) gramsEl.textContent = t.gramsEquiv(grams, kcal);
    if (sliderEl && !state.revealed) sliderEl.value = String(count);

    // Enable/disable minus buttons
    var btnM1 = document.getElementById("cds-btn-m1");
    var btnM5 = document.getElementById("cds-btn-m5");
    var btnP1 = document.getElementById("cds-btn-p1");
    var btnP5 = document.getElementById("cds-btn-p5");

    if (btnM1) btnM1.disabled = state.revealed || count < 1;
    if (btnM5) btnM5.disabled = state.revealed || count < 5;
    if (btnP1) btnP1.disabled = state.revealed || count >= 75;
    if (btnP5) btnP5.disabled = state.revealed || count > 70;
  }

  function pickRoundProducts() {
    var pool = CURATED_PRODUCTS.filter(function (p) {
      if (state.category === "all") return true;
      return p.cat === state.category;
    });
    if (pool.length < state.tries) pool = CURATED_PRODUCTS.slice();

    // Prioritize unseen products
    var unseen = pool.filter(function (p) {
      return !state.usedCodes[p.code];
    });
    if (unseen.length < state.tries) {
      state.usedCodes = {};
      unseen = pool.slice();
    }

    // Shuffle
    for (var i = unseen.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var tmp = unseen[i];
      unseen[i] = unseen[j];
      unseen[j] = tmp;
    }

    state.roundProducts = unseen.slice(0, state.tries);
    state.roundProducts.forEach(function (p) {
      state.usedCodes[p.code] = true;
    });
  }

  function startNewRound(firstCustomProduct) {
    state.roundIndex = 0;
    state.roundHistory = [];
    pickRoundProducts();
    if (firstCustomProduct) {
      state.roundProducts[0] = firstCustomProduct;
    }
    var summaryModal = document.getElementById("cds-summary-modal");
    if (summaryModal) summaryModal.style.display = "none";
    loadCurrentProduct();
  }

  function loadCurrentProduct() {
    state.revealed = false;
    state.guessCubes = 0;
    state.currentProduct = state.roundProducts[state.roundIndex] || CURATED_PRODUCTS[0];
    initPhysicsWorld();
    renderProductCard();
    updateCounterUI();
    updateRoundHeader();
  }

  function updateRoundHeader() {
    var t = I18N[state.lang];
    var stepText = document.getElementById("cds-step-label");
    var scoreText = document.getElementById("cds-score-label");
    var dotsContainer = document.getElementById("cds-step-dots");

    var totalScore = state.roundHistory.reduce(function (acc, item) {
      return acc + item.points;
    }, 0);

    if (stepText) {
      stepText.textContent = t.productStep + " " + (state.roundIndex + 1) + " / " + state.tries;
    }
    if (scoreText) {
      scoreText.textContent = t.scoreLabel + " : " + totalScore + " / " + state.roundHistory.length * 10 + " " + t.pointsUnit;
    }

    if (dotsContainer) {
      var html = "";
      for (var i = 0; i < state.tries; i++) {
        var h = state.roundHistory[i];
        var cls = "cds-dot";
        var label = String(i + 1);
        if (h) {
          cls += h.points >= 8 ? " cds-dot-great" : h.points >= 5 ? " cds-dot-ok" : " cds-dot-low";
          label = h.points + "p";
        } else if (i === state.roundIndex) {
          cls += " cds-dot-active";
        }
        html += '<span class="' + cls + '">' + label + "</span>";
      }
      dotsContainer.innerHTML = html;
    }
  }

  function renderProductCard() {
    var t = I18N[state.lang];
    var prod = state.currentProduct;
    if (!prod) return;

    var m = computeMetrics(prod, state.scaleMode);

    var titleEl = document.getElementById("cds-product-title");
    var brandEl = document.getElementById("cds-product-brand");
    var qtyEl = document.getElementById("cds-product-qty");
    var imgEl = document.getElementById("cds-product-img");
    var questionEl = document.getElementById("cds-question-box");
    var controlsEl = document.getElementById("cds-controls-box");
    var revealEl = document.getElementById("cds-reveal-box");
    var scalePkgBtn = document.getElementById("cds-scale-pkg");
    var scale100Btn = document.getElementById("cds-scale-100g");

    if (titleEl) titleEl.textContent = m.name;
    if (brandEl) brandEl.textContent = m.brands;
    if (qtyEl) qtyEl.textContent = m.qtyLabel;

    if (scalePkgBtn && scale100Btn) {
      scalePkgBtn.textContent = t.scalePackage + " (" + (prod.quantity || "100 g") + ")";
      scale100Btn.textContent = t.scale100g;
      scalePkgBtn.className = "cds-chip " + (state.scaleMode === "package" ? "cds-chip-active" : "");
      scale100Btn.className = "cds-chip " + (state.scaleMode === "100g" ? "cds-chip-active" : "");
    }

    if (imgEl) {
      var fallbackUri = makeFallbackSvg(m.emoji, m.name);
      imgEl.onerror = function () {
        imgEl.onerror = null;
        imgEl.src = fallbackUri;
      };
      imgEl.src = m.img || fallbackUri;
      imgEl.alt = m.name;
    }

    if (questionEl) {
      questionEl.innerHTML = t.questionPrompt(m.qtyLabel, m.name);
      questionEl.style.display = "block";
    }
    if (controlsEl) controlsEl.style.display = "block";
    if (revealEl) revealEl.style.display = "none";
  }

  function validateAnswer() {
    if (state.revealed || !state.currentProduct) return;
    state.revealed = true;

    var t = I18N[state.lang];
    var prod = state.currentProduct;
    var m = computeMetrics(prod, state.scaleMode);
    var userGuess = physics.bodies.length;
    state.guessCubes = userGuess;

    var points = computePoints(userGuess, m.smallF);
    playRevealSound(points);

    // Adjust physical cubes to match reality!
    var targetCubes = m.small;
    if (targetCubes > userGuess) {
      var missing = targetCubes - userGuess;
      for (var i = 0; i < missing; i++) {
        spawnCube("brown", i);
      }
      addFloatingLabel("+" + missing + " cachés !", "#fbbf24");
    } else if (userGuess > targetCubes) {
      var excess = userGuess - targetCubes;
      for (var j = 0; j < excess; j++) {
        removeOneCube();
      }
      addFloatingLabel("-" + excess, "#f87171");
    }

    // Record in round history
    state.roundHistory.push({
      product: prod,
      metrics: m,
      guess: userGuess,
      actualSmall: m.small,
      actualSmallF: m.smallF,
      actualGrams: m.sugarsG,
      points: points
    });

    // Optional server logging for combiendesucres.fr
    try {
      if (window.location.protocol.indexOf("http") === 0) {
        var formData = new URLSearchParams();
        formData.append("product", String(state.roundHistory.length));
        formData.append("code", prod.real_code || prod.code || "");
        formData.append("name", m.name);
        formData.append("actual", String(m.smallF));
        formData.append("answer", String(userGuess));
        formData.append("points", String(points));
        fetch("/cgi/sugar_check.pl", { method: "POST", body: formData }).catch(function () {});
      }
    } catch (e) {}

    // Show Reveal Panel
    var revealEl = document.getElementById("cds-reveal-box");
    var controlsEl = document.getElementById("cds-controls-box");
    if (controlsEl) controlsEl.style.display = "none";

    var titleText = t.revealTitleGood;
    var badgeClass = "cds-badge-good";
    if (points === 10) {
      titleText = t.revealTitlePerfect;
      badgeClass = "cds-badge-perfect";
    } else if (points >= 8) {
      titleText = t.revealTitleGreat;
      badgeClass = "cds-badge-perfect";
    } else if (userGuess < m.small) {
      titleText = t.revealTitleUnder;
      badgeClass = "cds-badge-warn";
    } else if (userGuess > m.small) {
      titleText = t.revealTitleOver;
      badgeClass = "cds-badge-warn";
    }

    var whoPct = Math.round((m.sugarsG / 25) * 100);
    var nutriscoreHtml = "";
    if (m.nutriscore && ["a", "b", "c", "d", "e"].indexOf(m.nutriscore) !== -1) {
      nutriscoreHtml =
        '<span class="cds-nutriscore cds-ns-' +
        m.nutriscore +
        '">Nutri-Score ' +
        m.nutriscore.toUpperCase() +
        "</span>";
    }

    var isLast = state.roundIndex >= state.tries - 1;
    var nextLabel = isLast ? "🏆 " + t.btnSeeResults : t.btnNext + " →";

    if (revealEl) {
      revealEl.innerHTML =
        '<div class="cds-reveal-header ' +
        badgeClass +
        '">' +
        '<div class="cds-reveal-pts">' +
        points +
        " / 10 " +
        t.pointsUnit +
        "</div>" +
        '<div class="cds-reveal-verdict">' +
        titleText +
        "</div>" +
        "</div>" +
        '<div class="cds-compare-row">' +
        '<div class="cds-compare-box"><span>' +
        t.yourGuess +
        "</span><strong>" +
        userGuess +
        " ⬜</strong> (" +
        userGuess * 4 +
        " g)</div>" +
        '<div class="cds-compare-vs">VS</div>' +
        '<div class="cds-compare-box cds-compare-actual"><span>' +
        t.actualSugar +
        "</span><strong>" +
        m.smallF +
        " 🟫</strong> (" +
        m.sugarsG +
        " g)</div>" +
        "</div>" +
        '<p class="cds-reveal-desc">' +
        t.revealText(m.qtyLabel, m.name, m.url, m.sugarsG, m.smallF, m.bigF) +
        "</p>" +
        '<div class="cds-who-bar">' +
        '<div class="cds-who-fill" style="width:' +
        Math.min(100, whoPct) +
        '%;background:' +
        (whoPct > 100 ? "#ef4444" : whoPct > 50 ? "#f59e0b" : "#10b981") +
        '"></div>' +
        "</div>" +
        '<p class="cds-who-text">' +
        t.whoComparison(whoPct) +
        "</p>" +
        '<div class="cds-meta-links">' +
        nutriscoreHtml +
        '<a href="' +
        m.url +
        '" target="_blank" rel="noopener" class="cds-off-link">' +
        t.viewOnOFF +
        "</a>" +
        "</div>" +
        '<div class="cds-reveal-actions">' +
        '<button type="button" id="cds-btn-next" class="cds-btn-primary">' +
        nextLabel +
        "</button>" +
        '<button type="button" id="cds-btn-share-prod" class="cds-btn-secondary">🔗 ' +
        t.btnShareProduct +
        "</button>" +
        "</div>";

      revealEl.style.display = "block";

      var nextBtn = document.getElementById("cds-btn-next");
      if (nextBtn) {
        nextBtn.onclick = function () {
          if (isLast) {
            showRoundSummary();
          } else {
            state.roundIndex++;
            loadCurrentProduct();
          }
        };
      }

      var shareProdBtn = document.getElementById("cds-btn-share-prod");
      if (shareProdBtn) {
        shareProdBtn.onclick = function () {
          shareProductChallenge(prod, m);
        };
      }
    }

    updateRoundHeader();
    updateCounterUI();
  }

  function showRoundSummary() {
    var t = I18N[state.lang];
    var totalScore = 0;
    var exactCount = 0;
    var underCount = 0;
    var underCubes = 0;
    var overCount = 0;
    var overCubes = 0;

    var rowsHtml = "";
    for (var i = 0; i < state.roundHistory.length; i++) {
      var item = state.roundHistory[i];
      totalScore += item.points;
      var diff = item.guess - item.actualSmall;
      if (item.points === 10 || diff === 0) {
        exactCount++;
      } else if (diff < 0) {
        underCount++;
        underCubes += Math.abs(diff);
      } else {
        overCount++;
        overCubes += diff;
      }

      var emojiBadge = item.points >= 8 ? "🟩" : item.points >= 5 ? "🟨" : "🟧";
      rowsHtml +=
        '<div class="cds-sum-row">' +
        '<div class="cds-sum-prod">' +
        '<span class="cds-sum-emoji">' +
        emojiBadge +
        " " +
        (item.metrics.emoji || "🍽️") +
        "</span>" +
        "<div><strong>" +
        item.metrics.name +
        '</strong><div class="cds-sum-sub">' +
        item.metrics.qtyLabel +
        " • " +
        item.actualGrams +
        " g de sucre</div></div>" +
        "</div>" +
        '<div class="cds-sum-nums">' +
        "<span>" +
        t.yourGuess +
        " : <strong>" +
        item.guess +
        "</strong></span>" +
        "<span>" +
        t.actualSugar +
        " : <strong>" +
        item.actualSmallF +
        "</strong></span>" +
        '<span class="cds-sum-pts">' +
        item.points +
        "/10</span>" +
        "</div>" +
        "</div>";
    }

    var insightsHtml = "";
    if (exactCount > 0) insightsHtml += "<li>🎯 " + t.statExact(exactCount) + "</li>";
    if (underCount > 0) insightsHtml += "<li>🟫 " + t.statUnder(underCount, underCubes, underCubes * 4) + "</li>";
    if (overCount > 0) insightsHtml += "<li>⬜ " + t.statOver(overCount, overCubes) + "</li>";

    var modal = document.getElementById("cds-summary-modal");
    if (modal) {
      modal.innerHTML =
        '<div class="cds-summary-card">' +
        '<div class="cds-summary-top">' +
        "<h2>🏆 " +
        t.summaryTitle +
        "</h2>" +
        '<div class="cds-big-score">' +
        totalScore +
        " <span>/ " +
        state.tries * 10 +
        "</span></div>" +
        "<p>" +
        t.summarySubtitle(totalScore, state.tries * 10) +
        "</p>" +
        "</div>" +
        '<ul class="cds-insights-list">' +
        insightsHtml +
        "</ul>" +
        '<div class="cds-sum-table">' +
        rowsHtml +
        "</div>" +
        '<div class="cds-summary-actions">' +
        '<button type="button" id="cds-btn-replay" class="cds-btn-primary">🔄 ' +
        t.btnReplay +
        "</button>" +
        '<button type="button" id="cds-btn-share-round" class="cds-btn-secondary">📤 ' +
        t.shareScoreBtn +
        "</button>" +
        "</div>" +
        "</div>";
      modal.style.display = "flex";

      document.getElementById("cds-btn-replay").onclick = function () {
        startNewRound();
      };
      document.getElementById("cds-btn-share-round").onclick = function () {
        shareRoundScore(totalScore);
      };
    }
  }

  function showToast(msg) {
    var toast = document.getElementById("cds-toast");
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add("cds-toast-visible");
    setTimeout(function () {
      toast.classList.remove("cds-toast-visible");
    }, 2600);
  }

  function copyOrShare(title, text, url) {
    var t = I18N[state.lang];
    if (navigator.share) {
      navigator.share({ title: title, text: text, url: url }).catch(function () {});
      return;
    }
    var full = text + (url ? "\n" + url : "");
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(full).then(function () {
        showToast(t.copiedToast);
      });
    } else {
      showToast(t.copiedToast);
    }
  }

  function shareRoundScore(totalScore) {
    var t = I18N[state.lang];
    var lines = ["🍬 " + t.siteTitle + " — " + totalScore + "/" + state.tries * 10];
    state.roundHistory.forEach(function (h) {
      var sq = h.points >= 8 ? "🟩" : h.points >= 5 ? "🟨" : "🟧";
      lines.push(sq + " " + (h.metrics.emoji || "🍽️") + " " + h.metrics.name + " : " + h.guess + " vs " + h.actualSmallF + " morceaux");
    });
    copyOrShare(t.siteTitle, lines.join("\n"), "https://combiendesucres.fr/");
  }

  function shareProductChallenge(prod, m) {
    var t = I18N[state.lang];
    var code = prod.real_code || prod.code || "";
    var baseUrl = window.location.origin && window.location.origin !== "null" ? window.location.origin + window.location.pathname : "https://combiendesucres.fr/";
    var shareUrl = baseUrl + "?code=" + encodeURIComponent(code);
    var msg =
      state.lang === "fr"
        ? "🍬 Combien de morceaux de sucre y a-t-il dans " + m.qtyLabel + " de " + m.name + " ? Faites le test !"
        : "🍬 How many sugar cubes are in " + m.qtyLabel + " of " + m.name + "? Take the test!";
    copyOrShare(t.siteTitle, msg, shareUrl);
  }

  // =========================================================================
  // OPEN FOOD FACTS LIVE SEARCH & BARCODE API
  // =========================================================================
  function parseOFFProduct(p) {
    if (!p || !p.nutriments) return null;
    var sugars100 = parseFloat(p.nutriments.sugars_100g);
    if (isNaN(sugars100) || sugars100 < 0) return null;
    var name = p.product_name_fr || p.product_name || p.generic_name || "";
    if (!name) return null;
    var qtyNum = parseFloat(p.product_quantity) || 100;
    var qtyStr = p.quantity || qtyNum + " g";
    var unit = /ml|cl|dl|\bl\b/i.test(qtyStr) ? "ml" : "g";
    if (qtyNum > 2000) qtyNum = 100; // sanity cap

    return {
      code: p.code || String(Math.random()),
      name_fr: name,
      name_en: p.product_name_en || name,
      brands: p.brands || "Open Food Facts",
      quantity: qtyStr,
      product_quantity: qtyNum,
      unit: unit,
      sugars_100g: Math.round(sugars100 * 10) / 10,
      nutriscore: p.nutriscore_grade || "",
      cat: "all",
      emoji: "🛒",
      img: p.image_front_url || p.image_front_small_url || ""
    };
  }

  function performProductSearch(query) {
    var t = I18N[state.lang];
    var resultsEl = document.getElementById("cds-search-results");
    if (!resultsEl) return;

    var q = (query || "").trim();
    // First match against curated products
    var localMatches = CURATED_PRODUCTS.filter(function (p) {
      if (!q) return true;
      var hay = (p.name_fr + " " + p.name_en + " " + p.brands + " " + p.code).toLowerCase();
      return hay.indexOf(q.toLowerCase()) !== -1;
    });

    renderSearchResults(localMatches, q.length > 1);

    if (!q) return;

    // If barcode (digits >= 8), fetch product directly from OFF API v2
    if (/^\d{8,14}$/.test(q)) {
      fetch("https://world.openfoodfacts.org/api/v2/product/" + encodeURIComponent(q) + ".json")
        .then(function (r) {
          return r.json();
        })
        .then(function (data) {
          if (data && data.product) {
            var parsed = parseOFFProduct(data.product);
            if (parsed) {
              renderSearchResults([parsed].concat(localMatches), false);
              return;
            }
          }
          renderSearchResults(localMatches, false);
        })
        .catch(function () {
          renderSearchResults(localMatches, false);
        });
      return;
    }

    // Live search on Open Food Facts
    var searchUrl =
      "https://fr.openfoodfacts.org/cgi/search.pl?search_terms=" +
      encodeURIComponent(q) +
      "&search_simple=1&action=process&json=1&page_size=12&fields=code,product_name,product_name_fr,product_name_en,brands,quantity,product_quantity,nutriments,image_front_small_url,image_front_url,nutriscore_grade";

    fetch(searchUrl)
      .then(function (r) {
        return r.json();
      })
      .then(function (data) {
        var apiProds = [];
        if (data && Array.isArray(data.products)) {
          data.products.forEach(function (raw) {
            var parsed = parseOFFProduct(raw);
            if (parsed) apiProds.push(parsed);
          });
        }
        var combined = localMatches.concat(apiProds);
        renderSearchResults(combined, false);
      })
      .catch(function () {
        renderSearchResults(localMatches, false);
      });
  }

  function renderSearchResults(list, isLoadingMore) {
    var t = I18N[state.lang];
    var resultsEl = document.getElementById("cds-search-results");
    if (!resultsEl) return;

    if (list.length === 0 && !isLoadingMore) {
      resultsEl.innerHTML = '<div class="cds-search-empty">' + t.searchNoResults + "</div>";
      return;
    }

    var html = isLoadingMore ? '<div class="cds-search-status">' + t.searchLoading + "</div>" : "";
    html += '<div class="cds-search-grid">';
    list.slice(0, 12).forEach(function (prod, idx) {
      var m = computeMetrics(prod, "package");
      var fallback = makeFallbackSvg(m.emoji, m.name);
      html +=
        '<div class="cds-search-item" data-idx="' +
        idx +
        '">' +
        '<img src="' +
        (m.img || fallback) +
        '" alt="" onerror="this.onerror=null;this.src=\'' +
        fallback +
        '\'" />' +
        '<div class="cds-search-item-info">' +
        "<strong>" +
        m.name +
        "</strong>" +
        "<span>" +
        m.brands +
        " • " +
        m.qtyLabel +
        "</span>" +
        "</div>" +
        '<button type="button" class="cds-btn-play-item" data-idx="' +
        idx +
        '">' +
        t.playThisProduct +
        " →</button>" +
        "</div>";
    });
    html += "</div>";
    resultsEl.innerHTML = html;

    var btns = resultsEl.querySelectorAll(".cds-btn-play-item");
    for (var i = 0; i < btns.length; i++) {
      (function (index) {
        btns[index].onclick = function () {
          var chosen = list[index];
          switchMode("quiz");
          startNewRound(chosen);
        };
      })(i);
    }
  }

  function switchMode(newMode) {
    state.mode = newMode;
    var quizView = document.getElementById("cds-quiz-view");
    var searchView = document.getElementById("cds-search-view");
    var sandboxView = document.getElementById("cds-sandbox-view");

    var tabQuiz = document.getElementById("cds-tab-quiz");
    var tabSearch = document.getElementById("cds-tab-search");
    var tabSandbox = document.getElementById("cds-tab-sandbox");

    if (quizView) quizView.style.display = newMode === "quiz" ? "block" : "none";
    if (searchView) searchView.style.display = newMode === "search" ? "block" : "none";
    if (sandboxView) sandboxView.style.display = newMode === "sandbox" ? "block" : "none";

    if (tabQuiz) tabQuiz.className = "cds-nav-tab " + (newMode === "quiz" ? "cds-tab-active" : "");
    if (tabSearch) tabSearch.className = "cds-tab-search cds-nav-tab " + (newMode === "search" ? "cds-tab-active" : "");
    if (tabSandbox) tabSandbox.className = "cds-nav-tab " + (newMode === "sandbox" ? "cds-tab-active" : "");

    if (newMode === "search") {
      var input = document.getElementById("cds-search-input");
      performProductSearch(input ? input.value : "");
      if (input) input.focus();
    } else if (newMode === "sandbox") {
      state.revealed = false;
      if (physics.bodies.length === 0) {
        for (var i = 0; i < 8; i++) spawnCube(i % 3 === 0 ? "brown" : "white", i);
      }
      updateCounterUI();
    }
  }

  // =========================================================================
  // BUILD / MOUNT MODERN RESPONSIVE INTERFACE
  // =========================================================================
  function injectModernStyles() {
    if (document.getElementById("cds-modern-styles")) return;
    var style = document.createElement("style");
    style.id = "cds-modern-styles";
    style.textContent =
      ":root { --cds-bg: #eff6ff; --cds-primary: #1d4ed8; --cds-primary-dark: #1e3a8a; --cds-accent: #f59e0b; --cds-card: #ffffff; --cds-text: #0f172a; --cds-muted: #475569; }" +
      "*, *::before, *::after { box-sizing: border-box; }" +
      "body, html { margin: 0; padding: 0; width: 100%; min-height: 100vh; font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(145deg, #1e3a8a 0%, #2563eb 55%, #1d4ed8 100%); color: #ffffff; -webkit-font-smoothing: antialiased; }" +
      "#page { max-width: 1120px; width: 100%; margin: 0 auto; padding: 16px 20px 48px 20px; background: transparent; }" +
      ".cds-topbar { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 14px; background: rgba(255, 255, 255, 0.96); color: var(--cds-text); padding: 12px 20px; border-radius: 20px; box-shadow: 0 12px 32px rgba(15, 23, 42, 0.22); margin-bottom: 20px; }" +
      ".cds-brand { display: flex; align-items: center; gap: 14px; text-decoration: none; color: inherit; }" +
      ".cds-brand img { height: 54px; width: auto; display: block; }" +
      ".cds-brand-text h1 { margin: 0; font-size: 1.35rem; font-weight: 800; color: #1e3a8a; letter-spacing: -0.02em; }" +
      ".cds-brand-text p { margin: 2px 0 0 0; font-size: 0.82rem; color: var(--cds-muted); }" +
      ".cds-nav { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }" +
      ".cds-nav-tab { border: none; background: #f1f5f9; color: #334155; font-weight: 600; font-size: 0.88rem; padding: 9px 15px; border-radius: 999px; cursor: pointer; transition: all 0.18s ease; }" +
      ".cds-nav-tab:hover { background: #e2e8f0; color: #0f172a; }" +
      ".cds-nav-tab.cds-tab-active { background: #1d4ed8; color: #ffffff; box-shadow: 0 4px 12px rgba(29, 78, 216, 0.3); }" +
      ".cds-util-btns { display: flex; align-items: center; gap: 6px; }" +
      ".cds-icon-btn { border: 1px solid #e2e8f0; background: #ffffff; color: #334155; font-weight: 700; font-size: 0.8rem; padding: 7px 11px; border-radius: 999px; cursor: pointer; transition: all 0.15s; }" +
      ".cds-icon-btn:hover { background: #f8fafc; border-color: #cbd5e1; }" +
      ".cds-grid { display: grid; grid-template-columns: 1.08fr 0.92fr; gap: 22px; align-items: start; }" +
      ".cds-card { background: rgba(255, 255, 255, 0.98); color: var(--cds-text); border-radius: 24px; padding: 22px; box-shadow: 0 16px 40px rgba(15, 23, 42, 0.25); position: relative; }" +
      ".cds-round-bar { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 10px; padding-bottom: 14px; margin-bottom: 14px; border-bottom: 1px solid #e2e8f0; }" +
      ".cds-step-info { display: flex; align-items: center; gap: 10px; font-weight: 700; font-size: 0.9rem; color: #1e3a8a; }" +
      ".cds-step-dots { display: flex; gap: 5px; }" +
      ".cds-dot { display: inline-flex; align-items: center; justify-content: center; min-width: 26px; height: 24px; padding: 0 6px; border-radius: 999px; font-size: 0.72rem; font-weight: 700; background: #e2e8f0; color: #64748b; }" +
      ".cds-dot-active { background: #1d4ed8; color: #ffffff; transform: scale(1.08); }" +
      ".cds-dot-great { background: #10b981; color: #ffffff; }" +
      ".cds-dot-ok { background: #f59e0b; color: #ffffff; }" +
      ".cds-dot-low { background: #ef4444; color: #ffffff; }" +
      ".cds-score-pill { background: #eff6ff; color: #1d4ed8; font-weight: 800; font-size: 0.88rem; padding: 6px 12px; border-radius: 999px; }" +
      ".cds-cat-bar { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 16px; }" +
      ".cds-cat-pill { border: 1px solid #e2e8f0; background: #f8fafc; color: #475569; font-size: 0.78rem; font-weight: 600; padding: 5px 11px; border-radius: 999px; cursor: pointer; transition: all 0.15s; }" +
      ".cds-cat-pill:hover { background: #eff6ff; color: #1d4ed8; }" +
      ".cds-cat-pill.cds-cat-active { background: #dbeafe; border-color: #93c5fd; color: #1e40af; font-weight: 700; }" +
      ".cds-product-showcase { display: grid; grid-template-columns: 150px 1fr; gap: 18px; align-items: center; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 18px; padding: 14px; margin-bottom: 16px; }" +
      ".cds-img-wrap { width: 150px; height: 150px; background: #ffffff; border-radius: 14px; display: flex; align-items: center; justify-content: center; overflow: hidden; cursor: zoom-in; box-shadow: 0 4px 12px rgba(0,0,0,0.05); position: relative; }" +
      ".cds-img-wrap img { max-width: 100%; max-height: 100%; object-fit: contain; transition: transform 0.2s; }" +
      ".cds-img-wrap:hover img { transform: scale(1.05); }" +
      ".cds-prod-details h2 { margin: 0 0 6px 0; font-size: 1.2rem; line-height: 1.3; color: #0f172a; }" +
      ".cds-badges { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 10px; }" +
      ".cds-badge { display: inline-block; font-size: 0.78rem; font-weight: 600; padding: 4px 10px; border-radius: 8px; background: #e2e8f0; color: #334155; }" +
      ".cds-badge-qty { background: #fef3c7; color: #92400e; font-weight: 700; }" +
      ".cds-scale-toggle { display: flex; flex-wrap: wrap; gap: 6px; }" +
      ".cds-chip { border: 1px solid #cbd5e1; background: #ffffff; color: #475569; font-size: 0.75rem; font-weight: 600; padding: 4px 10px; border-radius: 999px; cursor: pointer; }" +
      ".cds-chip-active { background: #1e3a8a; border-color: #1e3a8a; color: #ffffff; }" +
      ".cds-question-banner { background: #eff6ff; border-left: 4px solid #2563eb; padding: 12px 14px; border-radius: 10px; font-size: 0.96rem; line-height: 1.45; color: #1e3a8a; margin-bottom: 16px; }" +
      ".cds-counter-Readout { text-align: center; background: #0f172a; color: #ffffff; border-radius: 16px; padding: 12px; margin-bottom: 14px; }" +
      ".cds-counter-main { display: flex; align-items: baseline; justify-content: center; gap: 8px; }" +
      "#cds-cube-number { font-size: 2.6rem; font-weight: 900; color: #60a5fa; line-height: 1; }" +
      "#cds-cube-word { font-size: 1rem; font-weight: 600; color: #e2e8f0; }" +
      "#cds-grams-equiv { font-size: 0.82rem; color: #94a3b8; margin-top: 4px; }" +
      ".cds-btn-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; margin-bottom: 12px; }" +
      ".cds-step-btn { border: none; border-radius: 14px; padding: 12px 6px; font-size: 1.05rem; font-weight: 800; cursor: pointer; transition: transform 0.1s, background 0.15s; display: flex; flex-direction: column; align-items: center; gap: 2px; }" +
      ".cds-step-btn span { font-size: 0.7rem; font-weight: 600; opacity: 0.85; }" +
      ".cds-step-btn:active:not(:disabled) { transform: scale(0.95); }" +
      ".cds-step-btn:disabled { opacity: 0.4; cursor: not-allowed; }" +
      ".cds-btn-minus { background: #fee2e2; color: #b91c1c; }" +
      ".cds-btn-minus:hover:not(:disabled) { background: #fecaca; }" +
      ".cds-btn-plus { background: #dbeafe; color: #1d4ed8; }" +
      ".cds-btn-plus:hover:not(:disabled) { background: #bfdbfe; }" +
      ".cds-slider-wrap { display: flex; align-items: center; gap: 10px; margin-bottom: 14px; padding: 0 4px; }" +
      ".cds-slider-wrap input[type=range] { flex: 1; accent-color: #2563eb; height: 6px; cursor: pointer; }" +
      ".cds-btn-primary { width: 100%; border: none; background: linear-gradient(135deg, #16a34a 0%, #15803d 100%); color: #ffffff; font-size: 1.05rem; font-weight: 800; padding: 14px 20px; border-radius: 14px; cursor: pointer; box-shadow: 0 6px 18px rgba(22, 163, 74, 0.32); transition: transform 0.12s, box-shadow 0.15s; }" +
      ".cds-btn-primary:hover { transform: translateY(-1px); box-shadow: 0 8px 22px rgba(22, 163, 74, 0.4); }" +
      ".cds-btn-secondary { border: 1px solid #cbd5e1; background: #ffffff; color: #1e293b; font-size: 0.92rem; font-weight: 700; padding: 12px 16px; border-radius: 14px; cursor: pointer; transition: background 0.15s; }" +
      ".cds-btn-secondary:hover { background: #f1f5f9; }" +
      ".cds-reveal-header { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; border-radius: 14px; margin-bottom: 14px; color: #ffffff; }" +
      ".cds-badge-perfect { background: linear-gradient(135deg, #059669, #10b981); }" +
      ".cds-badge-good { background: linear-gradient(135deg, #2563eb, #3b82f6); }" +
      ".cds-badge-warn { background: linear-gradient(135deg, #d97706, #f59e0b); }" +
      ".cds-reveal-pts { font-size: 1.35rem; font-weight: 900; }" +
      ".cds-reveal-verdict { font-size: 0.95rem; font-weight: 700; }" +
      ".cds-compare-row { display: flex; align-items: center; gap: 10px; margin-bottom: 12px; }" +
      ".cds-compare-box { flex: 1; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 10px; text-align: center; font-size: 0.85rem; }" +
      ".cds-compare-box span { display: block; font-size: 0.75rem; color: #64748b; margin-bottom: 2px; }" +
      ".cds-compare-box strong { font-size: 1.15rem; color: #0f172a; }" +
      ".cds-compare-actual { background: #fffbeb; border-color: #fde68a; }" +
      ".cds-compare-vs { font-weight: 800; font-size: 0.78rem; color: #94a3b8; }" +
      ".cds-reveal-desc { font-size: 0.92rem; line-height: 1.5; color: #334155; margin: 0 0 12px 0; }" +
      ".cds-reveal-desc a { color: #1d4ed8; font-weight: 700; text-decoration: underline; }" +
      ".cds-who-bar { height: 8px; background: #e2e8f0; border-radius: 999px; overflow: hidden; margin-bottom: 6px; }" +
      ".cds-who-fill { height: 100%; border-radius: 999px; transition: width 0.4s ease; }" +
      ".cds-who-text { font-size: 0.8rem; color: #475569; margin: 0 0 12px 0; }" +
      ".cds-meta-links { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 14px; }" +
      ".cds-nutriscore { display: inline-block; font-weight: 800; font-size: 0.78rem; padding: 4px 10px; border-radius: 6px; color: #ffffff; }" +
      ".cds-ns-a { background: #038141; } .cds-ns-b { background: #85bb2f; } .cds-ns-c { background: #fecb02; color: #0f172a; } .cds-ns-d { background: #ee8100; } .cds-ns-e { background: #e63e11; }" +
      ".cds-off-link { font-size: 0.84rem; font-weight: 700; color: #1d4ed8; text-decoration: none; }" +
      ".cds-off-link:hover { text-decoration: underline; }" +
      ".cds-reveal-actions { display: grid; grid-template-columns: 1fr auto; gap: 10px; }" +
      ".cds-jar-card { background: rgba(15, 23, 42, 0.35); border: 1px solid rgba(255, 255, 255, 0.18); border-radius: 24px; padding: 14px; box-shadow: 0 16px 40px rgba(15, 23, 42, 0.3); text-align: center; }" +
      "#sugar_cubes { width: 100%; max-width: 450px; height: auto !important; margin: 0 auto; border-radius: 18px; overflow: hidden; position: relative; touch-action: none; background: #172554; box-shadow: inset 0 0 24px rgba(0,0,0,0.45); }" +
      "#sugar_cubes canvas { width: 100% !important; height: auto !important; display: block; cursor: grab; }" +
      "#sugar_cubes canvas:active { cursor: grabbing; }" +
      ".cds-jar-toolbar { display: flex; flex-wrap: wrap; align-items: center; justify-content: center; gap: 8px; margin-top: 10px; }" +
      ".cds-jar-btn { border: 1px solid rgba(255,255,255,0.25); background: rgba(255,255,255,0.12); color: #ffffff; font-size: 0.8rem; font-weight: 600; padding: 6px 12px; border-radius: 999px; cursor: pointer; transition: background 0.15s; }" +
      ".cds-jar-btn:hover { background: rgba(255,255,255,0.24); }" +
      ".cds-jar-hint { font-size: 0.78rem; color: #bfdbfe; margin: 8px 0 0 0; }" +
      ".cds-search-bar { display: flex; gap: 8px; margin-bottom: 14px; }" +
      ".cds-search-bar input { flex: 1; padding: 11px 14px; border: 1px solid #cbd5e1; border-radius: 12px; font-size: 0.92rem; }" +
      ".cds-search-grid { display: grid; grid-template-columns: 1fr; gap: 8px; max-height: 460px; overflow-y: auto; padding-right: 4px; }" +
      ".cds-search-item { display: flex; align-items: center; gap: 12px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 8px 12px; }" +
      ".cds-search-item img { width: 48px; height: 48px; object-fit: contain; background: #ffffff; border-radius: 8px; padding: 2px; }" +
      ".cds-search-item-info { flex: 1; min-width: 0; }" +
      ".cds-search-item-info strong { display: block; font-size: 0.88rem; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }" +
      ".cds-search-item-info span { font-size: 0.76rem; color: #64748b; }" +
      ".cds-btn-play-item { border: none; background: #dbeafe; color: #1d4ed8; font-weight: 700; font-size: 0.78rem; padding: 7px 12px; border-radius: 999px; cursor: pointer; white-space: nowrap; }" +
      ".cds-btn-play-item:hover { background: #1d4ed8; color: #ffffff; }" +
      ".cds-modal-backdrop { position: fixed; inset: 0; background: rgba(15, 23, 42, 0.75); backdrop-filter: blur(4px); z-index: 1000; display: none; align-items: center; justify-content: center; padding: 16px; overflow-y: auto; }" +
      ".cds-summary-card { background: #ffffff; color: #0f172a; max-width: 580px; width: 100%; border-radius: 24px; padding: 24px; box-shadow: 0 24px 60px rgba(0,0,0,0.4); }" +
      ".cds-summary-top { text-align: center; margin-bottom: 16px; }" +
      ".cds-summary-top h2 { margin: 0 0 8px 0; color: #1e3a8a; }" +
      ".cds-big-score { font-size: 3rem; font-weight: 900; color: #16a34a; line-height: 1; margin-bottom: 6px; }" +
      ".cds-big-score span { font-size: 1.3rem; color: #64748b; }" +
      ".cds-insights-list { background: #f8fafc; border-radius: 14px; padding: 12px 16px 12px 32px; margin: 0 0 16px 0; font-size: 0.88rem; line-height: 1.6; color: #334155; }" +
      ".cds-sum-table { display: flex; flex-direction: column; gap: 8px; margin-bottom: 18px; max-height: 260px; overflow-y: auto; }" +
      ".cds-sum-row { display: flex; align-items: center; justify-content: space-between; gap: 10px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 8px 12px; font-size: 0.84rem; }" +
      ".cds-sum-prod { display: flex; align-items: center; gap: 8px; }" +
      ".cds-sum-sub { font-size: 0.74rem; color: #64748b; }" +
      ".cds-sum-nums { display: flex; align-items: center; gap: 10px; white-space: nowrap; }" +
      ".cds-sum-pts { background: #1e3a8a; color: #ffffff; font-weight: 800; padding: 3px 8px; border-radius: 999px; font-size: 0.75rem; }" +
      ".cds-summary-actions { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }" +
      "#cds-toast { position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%) translateY(40px); background: #0f172a; color: #ffffff; padding: 10px 20px; border-radius: 999px; font-size: 0.88rem; font-weight: 600; opacity: 0; pointer-events: none; transition: all 0.25s ease; z-index: 2000; box-shadow: 0 10px 25px rgba(0,0,0,0.3); }" +
      "#cds-toast.cds-toast-visible { opacity: 1; transform: translateX(-50%) translateY(0); }" +
      "#content { margin-top: 32px; background: rgba(255, 255, 255, 0.1); border: 1px solid rgba(255, 255, 255, 0.18); border-radius: 24px; padding: 28px; color: #f8fafc; font-size: 0.95rem; line-height: 1.65; width: 100%; max-width: 100%; }" +
      "#content h2 { color: #fde047; margin-top: 24px; margin-bottom: 10px; font-size: 1.25rem; }" +
      "#content h2:first-child { margin-top: 0; }" +
      "#content a { color: #fde047; font-weight: 600; text-decoration: underline; }" +
      "#content img { border-radius: 12px; max-width: 100%; height: auto; }" +
      "@media (max-width: 900px) {" +
      "  #page { padding: 10px 12px 36px 12px; }" +
      "  .cds-grid { grid-template-columns: 1fr; }" +
      "  .cds-topbar { padding: 10px 14px; }" +
      "  .cds-brand img { height: 42px; }" +
      "  .cds-product-showcase { grid-template-columns: 110px 1fr; gap: 12px; padding: 10px; }" +
      "  .cds-img-wrap { width: 110px; height: 110px; }" +
      "}" +
      "@media (max-width: 520px) {" +
      "  .cds-product-showcase { grid-template-columns: 90px 1fr; }" +
      "  .cds-img-wrap { width: 90px; height: 90px; }" +
      "  .cds-prod-details h2 { font-size: 1.02rem; }" +
      "  .cds-reveal-actions, .cds-summary-actions { grid-template-columns: 1fr; }" +
      "}";
    document.head.appendChild(style);
  }

  function buildAppShell() {
    var t = I18N[state.lang];
    var page = document.getElementById("page");
    if (!page) return;

    // Check if legacy product was injected via inline script on an old static HTML page
    var legacyCustomProduct = null;
    if (typeof window.code === "string" && window.code && typeof window.small === "number" && window.small >= 0) {
      var legacyImgEl = document.querySelector("#products img");
      var legacyDescEl = document.getElementById("description");
      var qtyMatch = legacyDescEl ? legacyDescEl.textContent.match(/Quantit[eé]\s*:\s*([^\n]+)/i) : null;
      var qtyStr = qtyMatch ? qtyMatch[1].trim() : "1 portion";
      var actualSmallF = typeof window.small_f === "number" && window.small_f > 0 ? window.small_f : window.small;
      legacyCustomProduct = {
        code: window.code,
        name_fr: window.name || "Produit Open Food Facts",
        name_en: window.name || "Open Food Facts Product",
        brands: "Open Food Facts",
        quantity: qtyStr,
        product_quantity: 100,
        unit: "g",
        sugars_100g: actualSmallF * 4,
        nutriscore: "",
        cat: "all",
        emoji: "🛒",
        img: legacyImgEl ? legacyImgEl.src : ""
      };
    }

    // Preserve #content footer
    var contentEl = document.getElementById("content");
    var contentHtml = contentEl ? contentEl.outerHTML : "";

    var logoSrc = state.lang === "fr" ? "combien_de_sucres.png" : "how_much_sugar.png";

    page.innerHTML =
      '<header class="cds-topbar">' +
      '  <a href="/" class="cds-brand" id="cds-logo-link">' +
      '    <img src="' +
      logoSrc +
      '" alt="' +
      t.siteTitle +
      '" onerror="this.style.display=\'none\'" />' +
      '    <div class="cds-brand-text">' +
      "      <h1>" +
      t.siteTitle +
      "</h1>" +
      "      <p>" +
      t.tagline +
      "</p>" +
      "    </div>" +
      "  </a>" +
      '  <nav class="cds-nav">' +
      '    <button type="button" id="cds-tab-quiz" class="cds-nav-tab cds-tab-active">🎮 ' +
      t.modeQuiz +
      "</button>" +
      '    <button type="button" id="cds-tab-search" class="cds-nav-tab">🔍 ' +
      t.modeSearch +
      "</button>" +
      '    <button type="button" id="cds-tab-sandbox" class="cds-nav-tab">🧊 ' +
      t.modeSandbox +
      "</button>" +
      "  </nav>" +
      '  <div class="cds-util-btns">' +
      '    <button type="button" id="cds-btn-sound" class="cds-icon-btn" title="Audio">🔊</button>' +
      '    <button type="button" id="cds-btn-lang" class="cds-icon-btn">' +
      (state.lang === "fr" ? "🇬🇧 EN" : "🇫🇷 FR") +
      "</button>" +
      "  </div>" +
      "</header>" +
      '<main class="cds-grid">' +
      '  <section class="cds-card" id="cds-left-panel">' +
      '    <div id="cds-quiz-view">' +
      '      <div class="cds-round-bar">' +
      '        <div class="cds-step-info">' +
      '          <span id="cds-step-label">Produit 1 / 5</span>' +
      '          <div class="cds-step-dots" id="cds-step-dots"></div>' +
      "        </div>" +
      '        <div class="cds-score-pill" id="cds-score-label">Score : 0 pts</div>' +
      "      </div>" +
      '      <div class="cds-cat-bar" id="cds-cat-bar">' +
      '        <button type="button" class="cds-cat-pill cds-cat-active" data-cat="all">' +
      t.catAll +
      "</button>" +
      '        <button type="button" class="cds-cat-pill" data-cat="drinks">🥤 ' +
      t.catDrinks +
      "</button>" +
      '        <button type="button" class="cds-cat-pill" data-cat="breakfast">🥣 ' +
      t.catBreakfast +
      "</button>" +
      '        <button type="button" class="cds-cat-pill" data-cat="sweet">🍪 ' +
      t.catSweet +
      "</button>" +
      '        <button type="button" class="cds-cat-pill" data-cat="dairy">🍓 ' +
      t.catDairy +
      "</button>" +
      '        <button type="button" class="cds-cat-pill" data-cat="savory">🍅 ' +
      t.catSavory +
      "</button>" +
      "      </div>" +
      '      <div class="cds-product-showcase">' +
      '        <div class="cds-img-wrap" id="cds-img-zoom" title="' +
      t.zoomHint +
      '">' +
      '          <img id="cds-product-img" src="" alt="" />' +
      "        </div>" +
      '        <div class="cds-prod-details">' +
      '          <h2 id="cds-product-title"></h2>' +
      '          <div class="cds-badges">' +
      '            <span class="cds-badge" id="cds-product-brand"></span>' +
      '            <span class="cds-badge cds-badge-qty" id="cds-product-qty"></span>' +
      "          </div>" +
      '          <div class="cds-scale-toggle">' +
      '            <button type="button" id="cds-scale-pkg" class="cds-chip cds-chip-active">' +
      t.scalePackage +
      "</button>" +
      '            <button type="button" id="cds-scale-100g" class="cds-chip">' +
      t.scale100g +
      "</button>" +
      "          </div>" +
      "        </div>" +
      "      </div>" +
      '      <div class="cds-question-banner" id="cds-question-box"></div>' +
      '      <div id="cds-controls-box">' +
      '        <div class="cds-counter-Readout">' +
      '          <div class="cds-counter-main">' +
      '            <span id="cds-cube-number">0</span>' +
      '            <span id="cds-cube-word">' +
      t.cubesPlural +
      "</span>" +
      "          </div>" +
      '          <div id="cds-grams-equiv">≈ 0 g de sucre • 0 kcal</div>' +
      "        </div>" +
      '        <div class="cds-btn-row">' +
      '          <button type="button" id="cds-btn-m5" class="cds-step-btn cds-btn-minus">-5<span>-20 g</span></button>' +
      '          <button type="button" id="cds-btn-m1" class="cds-step-btn cds-btn-minus">-1<span>-4 g</span></button>' +
      '          <button type="button" id="cds-btn-p1" class="cds-step-btn cds-btn-plus">+1<span>+4 g</span></button>' +
      '          <button type="button" id="cds-btn-p5" class="cds-step-btn cds-btn-plus">+5<span>+20 g</span></button>' +
      "        </div>" +
      '        <div class="cds-slider-wrap">' +
      "          <span>0</span>" +
      '          <input type="range" id="cds-slider" min="0" max="75" value="0" />' +
      "          <span>75</span>" +
      "        </div>" +
      '        <button type="button" id="cds-btn-validate" class="cds-btn-primary">✓ ' +
      t.btnValidate +
      "</button>" +
      "      </div>" +
      '      <div id="cds-reveal-box" style="display:none"></div>' +
      "    </div>" +
      '    <div id="cds-search-view" style="display:none">' +
      '      <p style="margin-top:0;font-weight:600;color:#1e3a8a;">' +
      t.searchHint +
      "</p>" +
      '      <form id="cds-search-form" class="cds-search-bar">' +
      '        <input type="search" id="cds-search-input" placeholder="' +
      t.searchPlaceholder +
      '" />' +
      '        <button type="submit" class="cds-btn-secondary" style="background:#1d4ed8;color:#fff;border:none;">' +
      t.searchBtn +
      "</button>" +
      "      </form>" +
      '      <div id="cds-search-results"></div>' +
      "    </div>" +
      '    <div id="cds-sandbox-view" style="display:none">' +
      '      <h2 style="margin-top:0;color:#1e3a8a;">🧊 ' +
      t.sandboxTitle +
      "</h2>" +
      '      <p style="color:#475569;line-height:1.5;">' +
      t.sandboxDesc +
      "</p>" +
      '      <div class="cds-btn-row" style="grid-template-columns:1fr 1fr;margin-top:16px;">' +
      '        <button type="button" id="cds-sb-white" class="cds-step-btn cds-btn-plus">' +
      t.addWhite +
      " (+5)</button>" +
      '        <button type="button" id="cds-sb-brown" class="cds-step-btn" style="background:#fef3c7;color:#92400e;">' +
      t.addBrown +
      " (+5)</button>" +
      "      </div>" +
      '      <div style="display:flex;gap:10px;margin-top:10px;">' +
      '        <button type="button" id="cds-sb-shake" class="cds-btn-secondary" style="flex:1;">🌪️ ' +
      t.btnShake +
      "</button>" +
      '        <button type="button" id="cds-sb-clear" class="cds-btn-secondary" style="flex:1;">🧹 ' +
      t.btnClear +
      "</button>" +
      "      </div>" +
      "    </div>" +
      "  </section>" +
      '  <section class="cds-jar-card">' +
      '    <div id="sugar_cubes">' +
      '      <canvas id="c" width="450" height="650"></canvas>' +
      "    </div>" +
      '    <div class="cds-jar-toolbar">' +
      '      <button type="button" id="cds-jar-shake" class="cds-jar-btn">🌪️ ' +
      t.btnShake +
      "</button>" +
      '      <button type="button" id="cds-jar-photo" class="cds-jar-btn">📸 ' +
      t.btnPhoto +
      "</button>" +
      "    </div>" +
      '    <p class="cds-jar-hint">🐭 ' +
      t.mouseHint +
      "</p>" +
      '    <span id="cubes" style="display:none">0</span>' +
      "  </section>" +
      "</main>" +
      contentHtml +
      '<div id="cds-summary-modal" class="cds-modal-backdrop"></div>' +
      '<div id="cds-zoom-modal" class="cds-modal-backdrop" onclick="this.style.display=\'none\'">' +
      '  <img id="cds-zoom-img" src="" alt="" style="max-width:92vw;max-height:88vh;border-radius:18px;background:#fff;padding:12px;box-shadow:0 20px 50px rgba(0,0,0,0.5);" />' +
      "</div>" +
      '<div id="cds-toast"></div>';

    // Bind canvas
    physics.canvas = document.getElementById("c");
    physics.ctx = physics.canvas.getContext("2d");

    bindUIEvents();
    setupPointerEvents();

    // Check URL query parameters (?code=...)
    var params = new URLSearchParams(window.location.search);
    var urlCode = params.get("code");
    if (urlCode) {
      var foundLocal = CURATED_PRODUCTS.find(function (p) {
        return p.code === urlCode || p.real_code === urlCode;
      });
      if (foundLocal) {
        startNewRound(foundLocal);
      } else {
        startNewRound();
        fetch("https://world.openfoodfacts.org/api/v2/product/" + encodeURIComponent(urlCode) + ".json")
          .then(function (r) {
            return r.json();
          })
          .then(function (data) {
            if (data && data.product) {
              var parsed = parseOFFProduct(data.product);
              if (parsed) startNewRound(parsed);
            }
          })
          .catch(function () {});
      }
    } else {
      startNewRound(legacyCustomProduct);
    }
  }

  function bindUIEvents() {
    var logoLink = document.getElementById("cds-logo-link");
    if (logoLink) {
      logoLink.onclick = function (e) {
        e.preventDefault();
        switchMode("quiz");
        startNewRound();
      };
    }

    document.getElementById("cds-tab-quiz").onclick = function () {
      switchMode("quiz");
    };
    document.getElementById("cds-tab-search").onclick = function () {
      switchMode("search");
    };
    document.getElementById("cds-tab-sandbox").onclick = function () {
      switchMode("sandbox");
    };

    document.getElementById("cds-btn-sound").onclick = function () {
      state.soundEnabled = !state.soundEnabled;
      this.textContent = state.soundEnabled ? "🔊" : "🔇";
    };

    document.getElementById("cds-btn-lang").onclick = function () {
      state.lang = state.lang === "fr" ? "en" : "fr";
      buildAppShell();
    };

    // Category filter buttons
    var catBtns = document.querySelectorAll("#cds-cat-bar .cds-cat-pill");
    for (var i = 0; i < catBtns.length; i++) {
      catBtns[i].onclick = function () {
        state.category = this.getAttribute("data-cat") || "all";
        var all = document.querySelectorAll("#cds-cat-bar .cds-cat-pill");
        for (var k = 0; k < all.length; k++) all[k].classList.remove("cds-cat-active");
        this.classList.add("cds-cat-active");
        startNewRound();
      };
    }

    // Scale toggle (Whole package vs 100g)
    document.getElementById("cds-scale-pkg").onclick = function () {
      if (state.scaleMode !== "package") {
        state.scaleMode = "package";
        state.revealed = false;
        setCubeCount(0);
        renderProductCard();
      }
    };
    document.getElementById("cds-scale-100g").onclick = function () {
      if (state.scaleMode !== "100g") {
        state.scaleMode = "100g";
        state.revealed = false;
        setCubeCount(0);
        renderProductCard();
      }
    };

    // Image zoom modal
    document.getElementById("cds-img-zoom").onclick = function () {
      var src = document.getElementById("cds-product-img").src;
      var zModal = document.getElementById("cds-zoom-modal");
      var zImg = document.getElementById("cds-zoom-img");
      if (zModal && zImg && src) {
        zImg.src = src;
        zModal.style.display = "flex";
      }
    };

    // Cube step buttons
    document.getElementById("cds-btn-m5").onclick = function () {
      setCubeCount(physics.bodies.length - 5);
    };
    document.getElementById("cds-btn-m1").onclick = function () {
      setCubeCount(physics.bodies.length - 1);
    };
    document.getElementById("cds-btn-p1").onclick = function () {
      setCubeCount(physics.bodies.length + 1);
    };
    document.getElementById("cds-btn-p5").onclick = function () {
      setCubeCount(physics.bodies.length + 5);
    };

    var slider = document.getElementById("cds-slider");
    if (slider) {
      slider.oninput = function () {
        if (!state.revealed) {
          setCubeCount(parseInt(this.value, 10) || 0);
        }
      };
    }

    document.getElementById("cds-btn-validate").onclick = function () {
      validateAnswer();
    };

    // Jar toolbar
    document.getElementById("cds-jar-shake").onclick = function () {
      shakeCubes();
    };
    document.getElementById("cds-jar-photo").onclick = function () {
      save_drawing();
    };

    // Search form
    var searchForm = document.getElementById("cds-search-form");
    if (searchForm) {
      searchForm.onsubmit = function (e) {
        e.preventDefault();
        var q = document.getElementById("cds-search-input").value;
        performProductSearch(q);
      };
    }

    // Sandbox controls
    document.getElementById("cds-sb-white").onclick = function () {
      for (var s = 0; s < 5; s++) spawnCube("white", s);
      playCubeSound(physics.bodies.length);
    };
    document.getElementById("cds-sb-brown").onclick = function () {
      for (var s = 0; s < 5; s++) spawnCube("brown", s);
      playCubeSound(physics.bodies.length);
    };
    document.getElementById("cds-sb-shake").onclick = function () {
      shakeCubes();
    };
    document.getElementById("cds-sb-clear").onclick = function () {
      initPhysicsWorld();
    };
  }

  function setupPointerEvents() {
    function getStageCoords(e) {
      var canvas = physics.canvas;
      if (!canvas) return null;
      var rect = canvas.getBoundingClientRect();
      var clientX = e.clientX;
      var clientY = e.clientY;
      if (clientX === undefined && e.touches && e.touches.length > 0) {
        clientX = e.touches[0].clientX;
        clientY = e.touches[0].clientY;
      }
      if (clientX === undefined) return null;
      var sx = STAGE_W / (rect.width || STAGE_W);
      var sy = STAGE_H / (rect.height || STAGE_H);
      return {
        x: ((clientX - rect.left) * sx) / METER,
        y: ((clientY - rect.top) * sy) / METER
      };
    }

    function onMove(e) {
      var c = getStageCoords(e);
      if (c) {
        physics.mouseX = c.x;
        physics.mouseY = c.y;
      }
    }

    var container = document.getElementById("sugar_cubes");
    if (!container) return;

    container.addEventListener("mousedown", function (e) {
      physics.isPointerDown = true;
      onMove(e);
    });
    window.addEventListener("mousemove", function (e) {
      if (physics.isPointerDown) onMove(e);
    });
    window.addEventListener("mouseup", function () {
      physics.isPointerDown = false;
      physics.mouseX = undefined;
      physics.mouseY = undefined;
    });

    container.addEventListener(
      "touchstart",
      function (e) {
        physics.isPointerDown = true;
        onMove(e);
      },
      { passive: true }
    );
    container.addEventListener(
      "touchmove",
      function (e) {
        if (physics.isPointerDown) {
          onMove(e);
          if (physics.mouseJoint) e.preventDefault();
        }
      },
      { passive: false }
    );
    window.addEventListener("touchend", function () {
      physics.isPointerDown = false;
      physics.mouseX = undefined;
      physics.mouseY = undefined;
    });
  }

  // Keyboard shortcuts
  window.addEventListener("keydown", function (e) {
    if (e.target && (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA")) return;
    if (state.mode !== "quiz") return;
    if (!state.revealed) {
      if (e.key === "ArrowUp" || e.key === "+") {
        e.preventDefault();
        setCubeCount(physics.bodies.length + (e.shiftKey ? 5 : 1));
      } else if (e.key === "ArrowDown" || e.key === "-") {
        e.preventDefault();
        setCubeCount(physics.bodies.length - (e.shiftKey ? 5 : 1));
      } else if (e.key === "Enter") {
        e.preventDefault();
        validateAnswer();
      }
    } else if (e.key === "Enter" || e.key === " ") {
      var nextBtn = document.getElementById("cds-btn-next");
      if (nextBtn) {
        e.preventDefault();
        nextBtn.click();
      }
    }
  });

  // Expose legacy globals for compatibility
  window.save_drawing = function () {
    if (!physics.canvas) return;
    try {
      var dataUrl = physics.canvas.toDataURL("image/png");
      var a = document.createElement("a");
      a.href = dataUrl;
      a.download = "combien-de-sucres.png";
      a.click();
    } catch (e) {
      window.open(physics.canvas.toDataURL("image/png"));
    }
  };

  function initApp() {
    initSprites();
    injectModernStyles();
    buildAppShell();
    window.requestAnimationFrame(animationLoop);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initApp);
  } else {
    initApp();
  }
})();
