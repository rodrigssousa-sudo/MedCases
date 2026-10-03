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
  "prediabetes": "9774c09875969929abe08400d130e6d2e8fe3a84a3598c670dc6a7caf856c050",
  "deficiencia_vitamina_d": "b6cf499ea4a199b78c3412a427870036c535a35966bdd19193050c2d3fd47d7c",
  "nodulo_tireoidiano": "23a5ec5234aaf7afd4919bfb769f2ce04dba03c41ccdc3e9a74e8b8d2f89e0b8",
  "tireoidite_subaguda": "f938152341dda21d2e3631f91c823b26722c7a531f5c69bfab23fc02f956180f",
  "tireoidite_pos_parto": "8b396dfe3ab6d3e000ef9333a8ed6376d031ba2157e3b644643012bcaa1f5d48",
  "ginecomastia": "da77c61fa882d91843de5cb7fb098f84fbb7affdd84d83a9bb580d45b9cd011d",
  "bexiga_hiperativa": "612afae1a38eeb90e4cfb29644e8a6b21c1eebd3187b1a95222d06d89e8c9a15",
  "incontinencia_urinaria_adulto": "f7ab0d1e3b64d9ec0150363e3c915296724e4f9769a185891c498bc81ed1aa70",
  "disfuncao_eretil": "33a78b476acceab8cdd00f10261f74a83fb2298efe79761c969a8ee7a7a3ff30",
  "hipogonadismo_masculino": "f484dc0c66ef049666f3bde9ebf466ba1bdc021f0dabc46d049ce2dc6ad411bd",
  "prolapso_orgaos_pelvicos": "fbbd8b89fe9cb1c5de72bd943fad654710ed50e633a0456544031eedffa1ee2d",
  "sindrome_premenstrual_pmdd": "ed060a063129f11821c9271d68eb2d43c88403344b00c3278e6b28d21bccb378",
  "vulvodinia": "8aba81bc44e9aae1dbc9c38f97398f586a7b844e389999c13103225fb8d6cfaa",
  "insuficiencia_ovariana_prematura": "8857a0426b7f4384eb63e7939f8ace37cbdd65953eed43bf5acd42bd6e118063",
  "infertilidade": "8152cd8e50553f8867abca0db2c93262c8c00873b602755d681c1c349c6e6075",
  "ceratose_actinica": "d809236945f9f6066ceb4c3960113646c4586ca0431f37259a4ce28e95d0a884",
  "ceratose_seborreica": "80a30c88a46736721177fc867c11afc36b31c8090666d6f76715c20700eea431",
  "liquen_plano": "281175d886f27f1e1c4ee5d45cba2b48ce33ffe53c3b0f3bde8e2b500387de6e",
  "eritema_nodoso": "d92d6f3aabac2915d4a4b6cc8a0bb29c34c5dc28ef07f72b4a266f8fd3a89b0e",
  "eritema_multiforme": "140273d2289651d81019b4866c130897a95c814d5bd3bd1281f9fcfaa5105472",
  "queloide_cicatriz_hipertrofica": "0977a61f6011203a2afca119ce28bf411a97264800761eef6aad6551fde3b669",
  "lesao_por_pressao": "0b27a9d8177b2d3f03e9a3f65211d62abdffe27e82776db4d7ec56ea5e81ba63",
  "ulcera_venosa_membro_inferior": "10ff6643928946ba5f3fefa6d98db5fa510128405610c1d37881a76fd925fdb1",
  "ulcera_arterial_membro_inferior": "ea26ffa5e125f4a87907cebb641a2d4d3420f5dc1754ea77d33a56629d8c6be2",
  "ulcera_pe_diabetico": "5c5f861f9de387d830b23dd15702ce4cb6e1671847728963221d4c15bf686006",
  "linfedema": "fb8320c8548c64e505a346e7638f47637bfb7e6f643ee696b423a8832836bbd6",
  "sindrome_pos_trombotica": "b8c45ef9d00c3cf28d009c0534a3f7e06753c1e24811acc4449d8b1a10d70797",
  "halux_valgo": "d48e9b3fc0513f1e332c866dbbf457db5e8d2f03b3e19e3490d626855f64d11b",
  "neuroma_morton": "7248b1e8e3f0cf76354e35e576a901317be6c43045613c1c9bf7c3e69158e4cd",
  "epicondilite_medial": "556ef3aa88b43dd0ce1d586356e2301e41d9987a6ede9e292f386e1955651498",
  "contratura_dupuytren": "1ed93e17a5b2b58bdcdcb2f6932986bdd1cd63954886e8f166353668084e2e2a",
  "sindrome_tunel_cubital_neuropatia_ulnar": "b43664681a8f943fa536a4b91aef2465de853af26e86c69c6a3f3b1b81ce8699",
  "tendinopatia_biceps": "7ac4f400c01169bc477b894e956b3c0497c4a4b4802d2221c7a8d7a392408751",
  "sindrome_desfiladeiro_toracico": "27c57af920ef064bfd8abfec5bf20dbe2e5b003f33aebcc6d5773939b50b8f3c",
  "sarcopenia": "430e89f57803db3e3f9d4acd33b611d1ea2320a370d718dbe534ccffd1fc8b93",
  "sindrome_fragilidade": "c59e05f1c432fda659617c3c82164b372a4a3de2e750cee16afe34cda9bd72b0",
  "presbiacusia": "6f2d412968ff11cfd3c5b28ae1544c947798d7318b87d14763f935f4a5998b74",
  "degeneracao_macular_relacionada_idade": "74230e648b282656962d444055702534ea4305ce104a73055888f21cc3b86ad5",
  "retinopatia_diabetica": "caac1aa68e95bac20ce1c8bcf492e67975083a9f465fc5cca0a9ef8fdc30b039",
  "descolamento_retina": "1df8e7e6c729e298191b6fc9ad5808abd3b1c3c5c9fa53dc1097dcde938d5d1c",
  "alergia_alimentar": "ffe13c301a77706a2a9e1377e244d3e7c535542194f7aff8a8279269a2d61d0f",
  "ancilostomiase": "91d033f799b3a7cd24a290dafcdef5897dd4fca658321f5e1e3049800c5c6c84",
  "esquistossomose": "a60a73badf30eedc4059ed80e454d968f26c8c400d119066febd848bc31ea6e6",
  "hepatite_e": "98c61088b1e16a8cad952584460ecb63debf0ec5175a278c491e50719ca9d689",
  "acalasia": "4e256227db0191e60cc0e22d81184c176d421724a00ae7d12d39cb6bc5723692",
  "dor_abdominal_funcional_pediatrica": "a3b78d811fccdc3853e4aaec3198b63a44a081dc12c88a85fc8843329f144c7a",
  "crescimento_insuficiente_pediatrico": "c89a1f946ceb7b9bde831316e743a5162b768a64023f28a67da77e09d3bc2981",
  "transtorno_uso_tabaco_dependencia_nicotina": "7e7f1270b5ce2fe7da7e758eb2fdeedd2a6816550dc440819975c61d2fa616e9",
  "transtorno_uso_retirada_benzodiazepinicos": "ba86b9ae445b7379355a6a6bfebfea023d6e015defda87f82f08d2e54aada820",
  "neuralgia_occipital": "f9e3270d8dd22a1f0a3648397972df913ed3d39d5eec6849653e7db715c7191d",
  "acne_vulgar": "36417259f4095c8ae1861deacef9d18f8b8d5e8a9801395e672a1e1fc454a969",
  "rosacea": "068899d62930f8785ce5b71ce470d4cfe8a8ffb145297b33c07c676572f2cd8b",
  "psoriase": "5cc153e06d34d59124aca8fba719a44fa539f3d1a12091a3269c053c36aeb4c9",
  "dermatite_atopica": "3b9ec693890305a3381c7a14ae64623475d2bbe7b2026e1d6de07115bd8a0f40",
  "dermatite_contato": "f857e7496386a10c6171156aef7a7628231c3d536bfcbf130b0648360d727cc2",
  "dermatite_seborreica": "6c8aea90614a5dbbfc544ab6de65856e431ab291f02eb966828b322eeb17308b",
  "dermatite_periorificial": "c4932bdf5d0055eed0935683505541d7188aa04453eb38f5caa09612559180ce",
  "urticaria": "3d0d11a45c03dbf758d1dd948fabcee5442214543fd7f06ed98656d2b5739303",
  "vitiligo": "a9d3058763deb3352c6fdcbdd46a0a1e2fa22dfdf8f5169a2e58f803b4aa01b7",
  "melasma": "6089ca6b5736950ed73f3cb0b59ad445335acefa9c36454513cb81a1161d72dc",
  "alopecia_androgenetica": "b1bd792896aafd9f96d9e2499c87babef2f2ffe1f24b42641da2676511af0ee1",
  "alopecia_areata": "2a2f931b153e44d675d6fbf6d105564e63f28e22da382fc4a26bcd087c001538",
  "efluvio_telogeno": "9ac12bdeacbb488e879a43857b620cb53635e6c28f80e3fb171620487c488fef",
  "hiperidrose": "123da0da2931eda739f2368cfde4efec8da271926d20811480ea6be11593d83d",
  "ceratose_pilar": "5b0a90d6982df502f1efa66b9c757f26f376ce898e856384deffcfc87ea65620",
  "xerose_cutanea": "6d131ae0cbfe47227be750dc5793368096dc337ae5512405ad7545f1f24b55e2",
  "queimadura_solar": "e426a4f05568498f1506678b770d96e483ec497197aa7a9ae638c6df144905d4",
  "cisto_epidermoide_cutaneo": "d7edae79a4d2582ded73d5c11452ace0ba579dbbd7f2a2f16a208174f777aae7",
  "lipoma": "a7b98fbd681ece2250b366b658edf493e7adc6a34f8f96e32a049e466a6ba857",
  "dermatofibroma": "ea0ccdc5db53ee62987a918305a88de374d5aa3c6fcf07361b83b3238adec75f",
  "acrocordon": "74c489c0d32f77d870146f36e01ce431dc279b73bf42dfa8c522d73e3ed693eb",
  "milia": "cf7f39c7ecb96ac81133749e63e00a8b313b517e0705d720fe893c888a63b1c9",
  "angioma_rubi": "c28888606b04c4ef595ae26f65b699f444fa4f74bd860135a63d34c7f1d139c4",
  "nevo_melanocitico": "2c6601cccebafcfa122b33985bc355cb798c9ab445e87a4b03914a974698f1d6",
  "onicocriptose": "d2bb8da5f4bd7b12b552df9000c6ddd57f238806bf645e0f04dd4c57c024d9fa",
  "hidradenite_supurativa": "37e220494c806b48332bd9d7e5495ec8994fbfdc5dea1318b83a115685b47d98",
  "doenca_pilonidal": "770a50b01fad48982672a01cee3a1656b4ed1cbfc83ea44a75b2dd39eef75e43",
  "liquen_simplex_cronico": "27435e8bd941df5cadab9d0976d83aac0d8a201fad93c7c4ae6548682a467acd",
  "calos_calosidades": "6173b7aa1d275508845464967ded66776c413034c89eaea6dfaa342321fb8497",
  "hiperpigmentacao_pos_inflamatoria": "8c25bfb752c92794dd8e481d7f82c4ba68c549711b287027ee4951e324c394d1",
  "covid19": "c54ae5e151bb6ac453253b22ff915d323d694b798b8c6e5de89243310523dd99",
  "mononucleose_infecciosa": "e96634e699652a7bbf3d2ace31fb0656896bea756407cbb85ec7baf5f43f458d",
  "infeccao_hiv": "88b89f72fda1056ff102c61ad0bdd0e6634e641eba83cda1521b8455e384862e",
  "hepatite_a": "52e4efab757f95396f366b18fdd7c32db5cb926d91db86fd5c272e4aed9023ef",
  "sifilis": "b779ffbd36d3345d58f9bdd650ba7edd0e0c6f3f77ca90e646b82956b119e9fd",
  "infeccao_gonococica": "89d7869f45009610ee1cdcc4c692f63055223a6349e973453ae2ef08d6fc3a16",
  "infeccao_chlamydia_trachomatis": "eae762c3cb96e7811db1599ae467a6cab19a674b02b3bab8713b4d5a90c1426a",
  "tricomoniase": "fbd6b5f157931d1b50d16841d2c391d57622ceef36cfc74bc3917c6ffa8f4c40",
  "vaginose_bacteriana": "f8b84e37b3094a9cd5f2676d46a42b7e752a129d8d042373806529a8d43d726a",
  "candidiase_vulvovaginal": "9a37a1da3ea131c280da7c602e0fc4cefe9b783e96a2a2cffd82be4c018b63dc",
  "herpes_genital": "240f096f50b6db93c0197fdaa80bbb21276ce8d79f71b937edb923bc369bd73d",
  "herpes_zoster": "19d5d61720ceb0eb075d4652aca708c39ca75121a44e17918cf2ed16a0165900",
  "varicela": "c74a396aa50575189c1c7bbfba5880195b3e978ceef11ce17aab284763c2e437",
  "impetigo": "88235cd4c90b234c9c9a9c537444fdfed0245d740ebdfe82f0f44cf570461fc4",
  "escabiose": "f15152dd2756a532ed4c9a434ccf41d7e1979ba824c352ceffae4cbb25a57bbb",
  "pediculose": "7f1a0684f8d6355d8e2c54e27e8b072e986a3f8deeddb548fc308bc2aa74b5a5",
  "dermatofitose_cutanea": "b9e2f3abe586799b84c503f0a52696eb9d3d5dedd9056dd4443f0acbb01a8606",
  "coqueluche": "f1ffe5dd0b859f671365256b0465b039b3ca9171fde9ca7a09765d5991c6dc18",
  "doenca_mao_pe_boca": "6ce8630185eccafc10d0cec6582874fd1f54d3ef17695a30981af9eebbb75c56",
  "roseola_infantil": "426ef01a883acf5a0e2fd77e5b9b2b604a7625349b7876592438874fa5abb335",

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

// Exact version metadata for the fifty approved G03 owners.
const newPathologyG03Versions = <String, String>{
  "prediabetes": "NEW-JIT-2026-10-03-G03-v1.0",
  "deficiencia_vitamina_d": "NEW-JIT-2026-10-03-G03-v1.0",
  "nodulo_tireoidiano": "NEW-JIT-2026-10-03-G03-v1.0",
  "tireoidite_subaguda": "NEW-JIT-2026-10-03-G03-v1.0",
  "tireoidite_pos_parto": "NEW-JIT-2026-10-03-G03-v1.0",
  "ginecomastia": "NEW-JIT-2026-10-03-G03-v1.0",
  "bexiga_hiperativa": "NEW-JIT-2026-10-03-G03-v1.0",
  "incontinencia_urinaria_adulto": "NEW-JIT-2026-10-03-G03-v1.0",
  "disfuncao_eretil": "NEW-JIT-2026-10-03-G03-v1.0",
  "hipogonadismo_masculino": "NEW-JIT-2026-10-03-G03-v1.0",
  "prolapso_orgaos_pelvicos": "NEW-JIT-2026-10-03-G03-v1.0",
  "sindrome_premenstrual_pmdd": "NEW-JIT-2026-10-03-G03-v1.0",
  "vulvodinia": "NEW-JIT-2026-10-03-G03-v1.0",
  "insuficiencia_ovariana_prematura": "NEW-JIT-2026-10-03-G03-v1.0",
  "infertilidade": "NEW-JIT-2026-10-03-G03-v1.0",
  "ceratose_actinica": "NEW-JIT-2026-10-03-G03-v1.0",
  "ceratose_seborreica": "NEW-JIT-2026-10-03-G03-v1.0",
  "liquen_plano": "NEW-JIT-2026-10-03-G03-v1.0",
  "eritema_nodoso": "NEW-JIT-2026-10-03-G03-v1.0",
  "eritema_multiforme": "NEW-JIT-2026-10-03-G03-v1.0",
  "queloide_cicatriz_hipertrofica": "NEW-JIT-2026-10-03-G03-v1.0",
  "lesao_por_pressao": "NEW-JIT-2026-10-03-G03-v1.0",
  "ulcera_venosa_membro_inferior": "NEW-JIT-2026-10-03-G03-v1.0",
  "ulcera_arterial_membro_inferior": "NEW-JIT-2026-10-03-G03-v1.0",
  "ulcera_pe_diabetico": "NEW-JIT-2026-10-03-G03-v1.0",
  "linfedema": "NEW-JIT-2026-10-03-G03-v1.0",
  "sindrome_pos_trombotica": "NEW-JIT-2026-10-03-G03-v1.0",
  "halux_valgo": "NEW-JIT-2026-10-03-G03-v1.0",
  "neuroma_morton": "NEW-JIT-2026-10-03-G03-v1.0",
  "epicondilite_medial": "NEW-JIT-2026-10-03-G03-v1.0",
  "contratura_dupuytren": "NEW-JIT-2026-10-03-G03-v1.0",
  "sindrome_tunel_cubital_neuropatia_ulnar": "NEW-JIT-2026-10-03-G03-v1.0",
  "tendinopatia_biceps": "NEW-JIT-2026-10-03-G03-v1.0",
  "sindrome_desfiladeiro_toracico": "NEW-JIT-2026-10-03-G03-v1.0",
  "sarcopenia": "NEW-JIT-2026-10-03-G03-v1.0",
  "sindrome_fragilidade": "NEW-JIT-2026-10-03-G03-v1.0",
  "presbiacusia": "NEW-JIT-2026-10-03-G03-v1.0",
  "degeneracao_macular_relacionada_idade": "NEW-JIT-2026-10-03-G03-v1.0",
  "retinopatia_diabetica": "NEW-JIT-2026-10-03-G03-v1.0",
  "descolamento_retina": "NEW-JIT-2026-10-03-G03-v1.0",
  "alergia_alimentar": "NEW-JIT-2026-10-03-G03-v1.0",
  "ancilostomiase": "NEW-JIT-2026-10-03-G03-v1.0",
  "esquistossomose": "NEW-JIT-2026-10-03-G03-v1.0",
  "hepatite_e": "NEW-JIT-2026-10-03-G03-v1.0",
  "acalasia": "NEW-JIT-2026-10-03-G03-v1.0",
  "dor_abdominal_funcional_pediatrica": "NEW-JIT-2026-10-03-G03-v1.0",
  "crescimento_insuficiente_pediatrico": "NEW-JIT-2026-10-03-G03-v1.0",
  "transtorno_uso_tabaco_dependencia_nicotina": "NEW-JIT-2026-10-03-G03-v1.0",
  "transtorno_uso_retirada_benzodiazepinicos": "NEW-JIT-2026-10-03-G03-v1.0",
  "neuralgia_occipital": "NEW-JIT-2026-10-03-G03-v1.0",
};

// Exact version metadata for the fifty approved G04 owners.
const newPathologyG04Versions = <String, String>{
  "acne_vulgar": "NEW-JIT-2026-10-03-G04-v1.0",
  "rosacea": "NEW-JIT-2026-10-03-G04-v1.0",
  "psoriase": "NEW-JIT-2026-10-03-G04-v1.0",
  "dermatite_atopica": "NEW-JIT-2026-10-03-G04-v1.0",
  "dermatite_contato": "NEW-JIT-2026-10-03-G04-v1.0",
  "dermatite_seborreica": "NEW-JIT-2026-10-03-G04-v1.0",
  "dermatite_periorificial": "NEW-JIT-2026-10-03-G04-v1.0",
  "urticaria": "NEW-JIT-2026-10-03-G04-v1.0",
  "vitiligo": "NEW-JIT-2026-10-03-G04-v1.0",
  "melasma": "NEW-JIT-2026-10-03-G04-v1.0",
  "alopecia_androgenetica": "NEW-JIT-2026-10-03-G04-v1.0",
  "alopecia_areata": "NEW-JIT-2026-10-03-G04-v1.0",
  "efluvio_telogeno": "NEW-JIT-2026-10-03-G04-v1.0",
  "hiperidrose": "NEW-JIT-2026-10-03-G04-v1.0",
  "ceratose_pilar": "NEW-JIT-2026-10-03-G04-v1.0",
  "xerose_cutanea": "NEW-JIT-2026-10-03-G04-v1.0",
  "queimadura_solar": "NEW-JIT-2026-10-03-G04-v1.0",
  "cisto_epidermoide_cutaneo": "NEW-JIT-2026-10-03-G04-v1.0",
  "lipoma": "NEW-JIT-2026-10-03-G04-v1.0",
  "dermatofibroma": "NEW-JIT-2026-10-03-G04-v1.0",
  "acrocordon": "NEW-JIT-2026-10-03-G04-v1.0",
  "milia": "NEW-JIT-2026-10-03-G04-v1.0",
  "angioma_rubi": "NEW-JIT-2026-10-03-G04-v1.0",
  "nevo_melanocitico": "NEW-JIT-2026-10-03-G04-v1.0",
  "onicocriptose": "NEW-JIT-2026-10-03-G04-v1.0",
  "hidradenite_supurativa": "NEW-JIT-2026-10-03-G04-v1.0",
  "doenca_pilonidal": "NEW-JIT-2026-10-03-G04-v1.0",
  "liquen_simplex_cronico": "NEW-JIT-2026-10-03-G04-v1.0",
  "calos_calosidades": "NEW-JIT-2026-10-03-G04-v1.0",
  "hiperpigmentacao_pos_inflamatoria": "NEW-JIT-2026-10-03-G04-v1.0",
  "covid19": "NEW-JIT-2026-10-03-G04-v1.0",
  "mononucleose_infecciosa": "NEW-JIT-2026-10-03-G04-v1.0",
  "infeccao_hiv": "NEW-JIT-2026-10-03-G04-v1.0",
  "hepatite_a": "NEW-JIT-2026-10-03-G04-v1.0",
  "sifilis": "NEW-JIT-2026-10-03-G04-v1.0",
  "infeccao_gonococica": "NEW-JIT-2026-10-03-G04-v1.0",
  "infeccao_chlamydia_trachomatis": "NEW-JIT-2026-10-03-G04-v1.0",
  "tricomoniase": "NEW-JIT-2026-10-03-G04-v1.0",
  "vaginose_bacteriana": "NEW-JIT-2026-10-03-G04-v1.0",
  "candidiase_vulvovaginal": "NEW-JIT-2026-10-03-G04-v1.0",
  "herpes_genital": "NEW-JIT-2026-10-03-G04-v1.0",
  "herpes_zoster": "NEW-JIT-2026-10-03-G04-v1.0",
  "varicela": "NEW-JIT-2026-10-03-G04-v1.0",
  "impetigo": "NEW-JIT-2026-10-03-G04-v1.0",
  "escabiose": "NEW-JIT-2026-10-03-G04-v1.0",
  "pediculose": "NEW-JIT-2026-10-03-G04-v1.0",
  "dermatofitose_cutanea": "NEW-JIT-2026-10-03-G04-v1.0",
  "coqueluche": "NEW-JIT-2026-10-03-G04-v1.0",
  "doenca_mao_pe_boca": "NEW-JIT-2026-10-03-G04-v1.0",
  "roseola_infantil": "NEW-JIT-2026-10-03-G04-v1.0",
};
