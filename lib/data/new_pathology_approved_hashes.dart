// Exact owner and payload bindings approved by the human; clinical release only.
const newPathologyApprovedHashes = <String, String>{
  "laringite_aguda":
      "ef79ff6e35e384d0d904c3ae0766604748381ea0cff8a0f2316df8fb9acf629e",
  "foliculite":
      "374c11a526e80134b5f00b107fe984031b2dbac950f39e09b37b16ded5608180",
  "paroniquia":
      "40660a6a882c467eabf49c410f1a8fd12d01b960db8bd57fe775ef41a68346ef",
  "doenca_hemorroidaria":
      "cf3f9d249aff7dacd1c9435042fca5c35e17dbeaaa968ec875c545afdc906ec7",
  "fissura_anal":
      "1b23458fb07b9ccfe824431c90f3338855915aea9359ac89c6f8693824aa22ba",
  "colelitiase_colica_biliar":
      "85e077136b58b140e0779e54543eb41891d3548b22e484e93f028e7e8fbc2f3d",
  "retencao_urinaria_aguda":
      "95e0856650018f427d042cc5bc3261c02aa0c68a5329a87b79be47c624601dc9",
  "infeccao_odontogenica_abscesso_dentario":
      "028c7f892c0ee6180f1bff88a215608dc7bfca005bfbf594330730ed1514b1aa",
  "abscesso_perianal_fistula_anal":
      "e057d05b37bd90ee831d6f98825943c278ae5ea09eaed37201e62b5607f8f207",
  "cisto_abscesso_bartholin":
      "bfaf65ea7ddb7bfb0a605f143c2d5592cf7474119705f915c25d3036d7e27732",
  "dismenorreia_primaria_secundaria":
      "311f40d6a19584db941f129f911ddc2bde9a758b0bec1ccbff325c2b6244f5d0",
  "constipacao_funcional_pediatrica":
      "9d2df1ef4c904a1271b32f269b87dd67b6c74213c1f67a14be2868508184483b",
  "hordeolo_calazio":
      "44a0455079b6f06d7db2eeedcabbdf17365c38f721ca6f03902ff25314575c79",
  "impactacao_cerumen":
      "2c1ad0d2a71928f0e4c43a84114cc26d090f0823786fcabf7f03b859b0421237",
  "candidiase_oral":
      "d79598ed5a0ca975d18af49cc4e300e4e72d4c809e70fb974343347c7f78d983",
  "herpes_labial_recorrente":
      "f90ac18845135353c5a15bca8c2448a8438c0c68f6d3023f409c5480845ef54a",
  "intertrigo":
      "61e67bcc03433f7de4c4db5ef8275a662ab49e83587d83f962b4910b4a1b95c5",
  "estomatite_aftosa_recorrente":
      "b5d5dbeabbcb4fa9cc8ffa78a2790061c0ff20c1072b951864280d5a0903982a",
  "giardiase":
      "274003c56aeadcb3540b43301fc601e3f650cd4dfa8c12109d5de8c1a53d3813",
  "enterobiase":
      "98766d348a665dc2b93cfff04e015d7c5d5d96e730fad12a0c6d5b8133898440",
  "mastite_lactacional":
      "c597aa42e0ebca193e93e0176e07df64cbf9eef804380d3398a38e66dd928a8a",
  "linfadenite_cervical_bacteriana_aguda_pediatrica":
      "05d2b6fb3f4854588b6397df0ec9d11458c9dc6863877b1b6192237d91a93c47",
  "coledocolitiase":
      "f7ba215c636e6d106d6b2b58068ce1734d61ab77faff0eb1f2ff3bac49cfc625",
  "bursite_pre_patelar":
      "4f3627c3c4f8efa8cb07ca3ce92e822ec45a19d93ec550fb3c23f0632ab683fa",
  "epicondilite_lateral":
      "ccac72e85fc280a0440f62ab6f10769874ec0f3363a2eb5435567c468aeccdee",
  "fasciite_plantar":
      "c01c4dab3fc21506041a60985fd7f5fe323992fded9302a45240505ffa61282a",
  "radiculopatia_cervical":
      "7ac6e2145b1aef3a5ad9f85a694920251eb13d598fed896b023068eec671fbc6",
  "cefaleia_uso_excessivo_medicamentos":
      "77b2c90c4f41a5d5b9e410b5b9cfde18acd624b102b7056f98787822d651750d",
  "raiva_exposicao_raiva":
      "8189fa9ccc84a34e084efcda418a2bec4af55f8809fe4136eca42631758d3081",
  "cisto_ovariano_massa_anexial_benigna":
      "db9aa158a8b89e2ad319499d80be8353de76eb637070485efee2a1bbf73e699d",
  "blefarite_disfuncao_glandulas_meibomio":
      "74fa6ffb17fa2b9e4286dc9882bfdcfd39a6f6ada3bde97b9b87af703d968dba",
  "doenca_olho_seco":
      "3bd7dda33cbf50a27690e096d72a702444e7b1efe4cd134e7a5d929059e30cbc",
  "otite_media_com_efusao":
      "b613a631e1628496465b092ae6ca9bd95249615be8560893fb017703ea2f42b3",
  "disfuncao_tuba_auditiva":
      "739cdb4e5545ef8af6d0fabc29692b31fe00d6d0f375ec907e1ffb81e19ac303",
  "amebiase":
      "5d863e653074a98047130fe9b753b0497035927ecf9900fdc6f92ef04ad0cc17",
  "estrongiloidiase":
      "935d9cbaf43d5645f84fb92c77994dc98267ea68abd5d38cebfe758dfc61e5af",
  "pitiriase_rosea":
      "a0786f81f790e97cace4123618ee700fdbb5de2f9f81918882c8652d89d1e77e",
  "pitiriase_versicolor":
      "120eded1c837c6d2a14233d70573cd9961a5cfbe54580a417348bd6048d9ce4b",
  "molusco_contagioso":
      "ae6121fc334cdd5cb31b996e3e49b1c6fd331fb4067dbfe1d1ac5e23cb2f25d1",
  "verrugas_anogenitais_condiloma_acuminado":
      "c40ec96907550f885718af9ffb0c12d10035b988f1e436bccac7c77bca1ba813",
  "tendinopatia_aquiles":
      "cd2e54d21fd13fb445e6ef3a10a2b1c61c45e750cfdccec49ba32bd40e860036",
  "tenossinovite_de_quervain":
      "ef0fd4e531097afda6a12273b9aa8696006dbabe8ef81fe5a36e744b70848d87",
  "sindrome_dolorosa_trocanterica_maior":
      "f709254bca315d770c124f4a007372d67313325e6709721b4e64d8d87e1424c3",
  "sindrome_dor_femoropatelar":
      "9006c4ab41ea0798acbe90805c1e4d6e86bf16b16c2d3d75f7cdf971f2176dae",
  "bursite_pata_ganso":
      "7cc3b97633ad590a15d12ce2c7338a1c31ec17ce5d875cdc06158031cf44b72d",
  "capsulite_adesiva":
      "1e2acfa1a1f084741e7518dc96d5cd9b4203170276e74353499694c61e66add8",
  "doenca_meniere":
      "63d9d0c03811743ea93ff25717f9732d0bb465637397d5c668407a341f6c2a8e",
  "enurese_pediatrica":
      "5064c99f88155c2d77f6d65c54296f90ac254a14fd7a1cea83e6fd2c959375ad",
  "bacteriuria_assintomatica":
      "a829329171003ed73dd58f9db015b2289cd5bac0bd9aef992e2e46f4a96502fc",
  "amenorreia_secundaria":
      "185db22456496bf9cfe3d80359b7e409102f1093320783bb5ec56b1147333ad8",
  "carie_dentaria":
      "b87dd0e7c11fb98dd2eb5bb4c822cb8faf0fdb480b5ada9260b700e45c7fdb0e",
  "gengivite":
      "32e31a1ee79731f051d1794b8e1ce304fc2cc82c9a7bd3bc067d125d976e1f57",
  "periodontite":
      "4e0903fe5d49084532594f48cdc2679a99786ca2b0d2ef1feae5ff44affcdeb8",
  "disfuncao_temporomandibular":
      "b686b758d244e002db59ca5a75b410d0cf4ca90069342465d1c59d2d67115da0",
  "onicomicose":
      "569ab12dec8e449e9ae1812fd49fd3a0f29add99ac61c01741167691e915ae21",
  "cisto_baker":
      "95b7c7f607c6bd6bdbc82ac71d745792e2d6c35d7195935724683b18eb1f379f",
  "cisto_sinovial_punho":
      "c3e6b79380e8a516beabde5276e260de1870ff00d4a75a811fe2f18d3eef30d2",
  "dedo_em_gatilho":
      "c230c68eda9eb6731a9264bba18fc3b428d053c5385e851cf82ef2ee12e1ddef",
  "meralgia_parestesica":
      "763ac910cd1b9e1c926d46924c9a4d4210bc9c103e5ff38ea39ebc9f411fbe4c",
  "zumbido_tinnitus":
      "ef4c15f42194355da93a33bf019524b724d562cf0d07f56cc4580869b42eabe1",
};

// Version metadata for the approved G02 owners only.
const newPathologyG02Versions = <String, String>{
  "bacteriuria_assintomatica": "NEW-JIT-2026-10-02-G02-v1.0",
  "amenorreia_secundaria": "NEW-JIT-2026-10-02-G02-v1.0",
  "carie_dentaria": "NEW-JIT-2026-10-02-G02-v1.0",
  "gengivite": "NEW-JIT-2026-10-02-G02-v1.0",
  "periodontite": "NEW-JIT-2026-10-02-G02-v1.0",
  "disfuncao_temporomandibular": "NEW-JIT-2026-10-02-G02-v1.0",
  "onicomicose": "NEW-JIT-2026-10-02-G02-v1.0",
  "cisto_baker": "NEW-JIT-2026-10-02-G02-v1.0",
  "cisto_sinovial_punho": "NEW-JIT-2026-10-02-G02-v1.0",
  "dedo_em_gatilho": "NEW-JIT-2026-10-02-G02-v1.0",
  "meralgia_parestesica": "NEW-JIT-2026-10-02-G02-v1.0",
  "zumbido_tinnitus": "NEW-JIT-2026-10-02-G02-v1.0",
};
