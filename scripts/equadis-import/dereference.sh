perl -i -pe 's/gs1:T3783:250/France/g' $1
perl -i -pe 's/gs1:T3780:GRM/g/g' $1
perl -i -pe 's/gs1:T3780:MLT/mL/g' $1
perl -i -pe 's/gs1:T3780:MC/µg/g' $1
perl -i -pe 's/gs1:T3780:MGM/mg/g' $1
perl -i -pe 's/gs1:T3780:H87/pièces/g' $1

# https://gs1.se/en/guides/documentation/code-lists/t0137-packaging-type-code-2/
perl -i -pe 's/gs1:T0137:AE/aérosol/g' $1
perl -i -pe 's/gs1:T0137:BG/sac/g' $1
perl -i -pe 's/gs1:T0137:BO/bouteille/g' $1
perl -i -pe 's/gs1:T0137:BX/boite/g' $1
perl -i -pe 's/gs1:T0137:CS//g' $1
perl -i -pe 's/gs1:T0137:CT//g' $1
perl -i -pe 's/gs1:T0137:CU/pot/g' $1
perl -i -pe 's/gs1:T0137:CNG/can/g' $1
perl -i -pe 's/gs1:T0137:EN//g' $1
perl -i -pe 's/gs1:T0137:JR/bocal/g' $1
perl -i -pe 's/gs1:T0137:MPG/multipack/g' $1
perl -i -pe 's/gs1:T0137:PO/poche/g' $1
perl -i -pe 's/gs1:T0137:PUG//g' $1
perl -i -pe 's/gs1:T0137:TU/tube/g' $1
perl -i -pe 's/gs1:T0137:WRP/wrapper/g' $1

perl -i -pe 's/gs1:T4078:AC/Crustacés/g' $1
perl -i -pe 's/gs1:T4078:AE/Oeuf/g' $1
perl -i -pe 's/gs1:T4078:AF/Poisson/g' $1
perl -i -pe 's/gs1:T4078:AM/Lait/g' $1
perl -i -pe 's/gs1:T4078:AN/Fruits à coque/g' $1
perl -i -pe 's/gs1:T4078:AP/Cacahuètes/g' $1
perl -i -pe 's/gs1:T4078:AS/Sésame/g' $1
perl -i -pe 's/gs1:T4078:AU/Sulfites/g' $1
perl -i -pe 's/gs1:T4078:AW/Gluten/g' $1
perl -i -pe 's/gs1:T4078:AY/Soja/g' $1
perl -i -pe 's/gs1:T4078:BC/Céleri/g' $1
perl -i -pe 's/gs1:T4078:BM/Moutarde/g' $1
perl -i -pe 's/gs1:T4078:GB/Orge/g' $1
perl -i -pe 's/gs1:T4078:NL/Lupin/g' $1
perl -i -pe 's/gs1:T4078:SA/Amandes/g' $1
perl -i -pe 's/gs1:T4078:SB/Graines/g' $1
perl -i -pe 's/gs1:T4078:SH/Noisette/g' $1
perl -i -pe 's/gs1:T4078:SW/Noix/g' $1
perl -i -pe 's/gs1:T4078:UM/Mollusques/g' $1
perl -i -pe 's/gs1:T4078:UW/Blé/g' $1

perl -i -pe 's/AGRICULTURE_BIOLIGIQUE/AGRICULTURE_BIOLOGIQUE/g' $1
