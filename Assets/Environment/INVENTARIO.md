# Biblioteca ambiental

## Modelos integrados ao Bosque do Arco

| Categoria | Modelo original | Caminho no projeto | Pacote | Triângulos de origem |
| --- | --- | --- | --- | ---: |
| Árvore arredondada | `Tree_1_A_Color1` | `Trees/oak-rounded.gltf` | KayKit | 530 |
| Árvore de copa espalhada | `Tree_2_A_Color1` | `Trees/oak-spreading.gltf` | KayKit | 336 |
| Árvore alta | `Tree_4_A_Color1` | `Trees/tree-tall.gltf` | KayKit | 404 |
| Arbusto | `Bush_1_C_Color1` | `Shrubs/forest-shrub.gltf` | KayKit | 168 |
| Rocha | `Rock_3_E_Color1` | `Rocks/weathered-stone.gltf` | KayKit | 84 |
| Samambaia | `Fern_1` | `Plants/woodland-fern.gltf` | Quaternius | 288 |
| Flor silvestre | `Flower_3_Single` | `Flowers/trail-wildflower.gltf` | Quaternius | 285 |

- **KayKit Forest Nature Pack 1.0 Free**, de Kay Lousberg, sob [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Atlas compartilhado em `Materials/KayKit/`. Aviso do pacote em `Licenses/KayKit-CC0.txt`. O autor pede que não se revendam cópias inalteradas nem se reivindique autoria. [Fonte oficial](https://kaylousberg.itch.io/kaykit-forest)
- **Stylized Nature MegaKit Standard**, de Quaternius, sob [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Texturas com recorte alfa em `Materials/Quaternius/`. Aviso do pacote em `Licenses/Quaternius-CC0.txt`. [Fonte oficial](https://quaternius.com/packs/stylizednaturemegakit.html)

As escalas foram normalizadas para o cenário existente. O atlas do KayKit teve a saturação ajustada para a paleta de Aurelia. Os atlas foram reduzidos para até 256 px (KayKit) e 512 px (Quaternius), com mipmaps. Cada glTF mantém seu buffer binário e referencia as texturas compartilhadas. O bosque reutiliza os lotes MultiMesh e a distribuição existente, com LOD de importação e densidade menor no Econômico. Os ZIPs originais permanecem em Downloads.
