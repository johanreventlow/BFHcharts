# golden: stable data, no target, da, max=375

    Code
      cat(text)
    Output
      Processen varierer naturligt omkring midten i data og vurderes derfor som stabil og forudsigelig, uden tegn på systematiske ændringer. Overvej, om et udviklingsmål kan fastsættes, så det aktuelle niveau kan vurderes, og behovet for forbedring kan prioriteres.

# golden: stable data, no target, en, max=375

    Code
      cat(text)
    Output
      The process is stable and predictable. Variation is natural and shows no signs of systematic change. Consider setting a target for the indicator so the current level can be assessed and the need for improvement can be prioritised.

# golden: constant data (no_variation override)

    Code
      cat(text)
    Output
      Niveauet ligger fast på 50. Da alle datapunkter er identiske, kan processen ikke vurderes med statistisk proceskontrol. Overvej, om et udviklingsmål kan fastsættes, så det aktuelle niveau kan vurderes, og behovet for forbedring kan prioriteres.

# golden: short data (low confidence -> not_evaluable)

    Code
      cat(text)
    Output
      Med kun 8 observationer er datagrundlaget for spinkelt til pålidelig vurdering med statistisk proceskontrol. Anhøj-reglerne kræver typisk mindst 12 observationer for at have detektionsstyrke.

# golden: shifted data (runs_only signal)

    Code
      cat(text)
    Output
      Processen er ustabil med flere samtidige signaler: niveauskift og gruppering samt 6 af de seneste 6 observationer uden for kontrolgrænserne. Undersøg årsagerne til variationen. Når processen er under kontrol, kan et realistisk mål sættes og forbedringsindsatsen planlægges.

# golden: stable + target='<= 100' (direction-aware lower)

    Code
      cat(text)
    Output
      Processen varierer naturligt omkring midten i data og vurderes derfor som stabil og forudsigelig, uden tegn på systematiske ændringer. Det nuværende niveau på 50,29 opfylder udviklingsmålet (≤ 100). Fortsæt den nuværende praksis, men hold løbende øje med data, så niveauet kan fastholdes og evt. forandring fanges tidligt.

# golden: stable + target='>= 40' (direction-aware higher)

    Code
      cat(text)
    Output
      Processen varierer naturligt omkring midten i data og vurderes derfor som stabil og forudsigelig, uden tegn på systematiske ændringer. Det nuværende niveau på 50,29 opfylder udviklingsmålet (≥ 40). Fortsæt den nuværende praksis, men hold løbende øje med data, så niveauet kan fastholdes og evt. forandring fanges tidligt.

# golden: phased data + higher_better direction (full modifier-cascade)

    Code
      cat(text)
    Output
      Processen varierer naturligt omkring midten i data og vurderes derfor som stabil og forudsigelig, uden tegn på systematiske ændringer. Sammenlignet med tidligere fase er niveauet flyttet fra 49,75 til 54,87, en betydelig niveauforandring på ~10% i den ønskede retning. Overvej, om et udviklingsmål kan fastsættes, så det aktuelle niveau kan vurderes, og behovet for forbedring kan prioriteres.

# golden: phased data + lower_better direction (unfavorable cascade)

    Code
      cat(text)
    Output
      Processen varierer naturligt omkring midten i data og vurderes derfor som stabil og forudsigelig, uden tegn på systematiske ændringer. Sammenlignet med tidligere fase er niveauet flyttet fra 49,75 til 54,87, en betydelig niveauforandring på ~10% væk fra den ønskede retning. Overvej, om et udviklingsmål kan fastsættes, så det aktuelle niveau kan vurderes, og behovet for forbedring kan prioriteres.

# golden: cl=specified (cl_user_supplied caveat)

    Code
      cat(text)
    Output
      Processen varierer naturligt omkring midten i data og vurderes derfor som stabil og forudsigelig, uden tegn på systematiske ændringer. Overvej, om et udviklingsmål kan fastsættes, så det aktuelle niveau kan vurderes, og behovet for forbedring kan prioriteres. Midtlinje fastsat manuelt — Anhøj-signal beregnet mod denne, ikke data-estimeret middelværdi.

# golden: max_chars=200 (kortere trim-boundary)

    Code
      cat(text)
    Output
      Processen er stabil og forudsigelig. Målet (≥ 40) er nået. Fortsæt den nuværende praksis, og hold løbende øje med data.

# golden: max_chars=100 (aggressiv trim-boundary)

    Code
      cat(text)
    Output
      Processen er stabil og forudsigelig. Målet (≥ 40) er nået. Fortsæt den nuværende praksis.

