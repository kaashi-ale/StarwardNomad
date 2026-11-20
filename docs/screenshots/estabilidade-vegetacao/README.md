# Estabilidade da vegetação em voo

Cada imagem acompanha uma manobra na cena principal de Godot 4.3 Compatibility. A linha superior mostra a geração anterior e a inferior mostra a revisão. Parada, fim da pequena manobra e retorno usam a mesma direção, altura e orientação. Na coluna de altitude a câmera já percorreu 480 m.

O teste move a nave por uma trajetória programada, suspende sua física de pilotagem e mantém ativos o terreno, o streaming e o FloatingOrigin. Parte de um bosque próximo à junção das faces +X/+Z, paira por cinco segundos após o aquecimento, gira a câmera, oscila até 7 m longitudinalmente e 6 m lateralmente, percorre aproximadamente 480 m em voo baixo, sobe até 275 m e regressa. A altura é relativa ao terreno. As imagens individuais de altitude mostram o mesmo bosque visto de cima a 175 m no Econômico. A posição de referência é registrada no espaço local do planeta.

## Resultados no PC

As colunas com pares indicam antes / depois. Uma aparição próxima é uma posição que entra no conjunto desenhado a menos de 65 m da nave. Os contadores leem as transformações dos MultiMeshes, inclusive os lotes fora do enquadramento. O teste compara posições com resolução de 5 cm a cada dez quadros. A coluna de voo alto conta árvores ativas a mais de 230 m durante a subida. O p95 mede a etapa de ida em milissegundos.

| Planeta | Perfil | Aparições próximas na pequena manobra | Setores reconstruídos na pequena manobra | Árvores próximas presentes no retorno | Árvores distantes em altitude | p95 de ida (ms) |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Glacius IX | Econômico | 59 / 0 | 4 / 0 | 27 de 27 | 92 | 43.5 / 50.6 |
| Glacius IX | Baixo | 77 / 0 | 0 / 0 | 36 de 36 | 215 | 43.1 / 44.1 |
| Aurelia Prime | Econômico | 62 / 0 | 4 / 0 | 17 de 17 | 318 | 112.9 / 91.6 |
| Aurelia Prime | Baixo | 74 / 0 | 4 / 0 | 29 de 29 | 626 | 109.4 / 91.6 |
| Veridian Mire | Econômico | 55 / 0 | 5 / 0 | 24 de 24 | 426 | 49.5 / 67.5 |
| Veridian Mire | Baixo | 66 / 0 | 2 / 0 | 46 de 46 | 847 | 84.3 / 67.7 |

O CSV contém as oito fases de cada sequência, incluindo setores criados, removidos e reconstruídos, instâncias ativas, mudanças próximas de cobertura rasteira, tempos de quadro e quadros acima de 50 ms. Uma reconstrução distante após sair da zona de retenção é esperada. As pausas de aquecimento incluem a chegada programada ao planeta. Hardware de teste: Celeron 1007U e Intel HD Graphics 2500, OpenGL Mesa, janela de 800 × 450. A simulação avançou com passo fixo de 30 Hz. Os tempos são de relógio no PC. No Moto G04s, o jogador mediu anteriormente 30 FPS no Econômico e 20–30 no Baixo. A nova versão aguarda medição no aparelho.

## Causa e correção

Antes, uma grade tangente móvel escolhia algumas chaves da face do cubo. Uma pequena mudança de direção mudava a lista, mesmo dentro do raio de exibição. Prazos de 1,25 s expiravam e a quantidade desenhada em cada MultiMesh encolhia com a distância. Um tronco perto da nave podia estar no fim desse lote. A geração também dependia de raios no mundo físico e dos sorteios consumidos depois de cada acerto.

Agora cada setor possui quatro quadriláteros fixos da malha física. Cada família de plantas usa sua própria semente e amostra os triângulos em coordenadas locais. Perto, as árvores usam os modelos Quaternius originais. A média distância usam a malha compacta e longe uma copa opaca ajustada aos limites do modelo. Os três níveis usam as mesmas transformações. O perfil seleciona uma fração estável das instâncias. O voo antecipa setores na direção da velocidade. A exibição, a retenção e o descarregamento têm limites distintos, e as trocas de malha têm histerese. As copas do bosque autoral também usam os três níveis.

Para reproduzir, execute `docs/tools/check_vegetation.gd` por caminho absoluto com o Godot gráfico, `--windowed --resolution 800x450 --fixed-fps 30`, `NOMAD_AUDIT_DIR` apontando para uma pasta gravável, `NOMAD_STAGE=depois`, `NOMAD_PLANET` igual a 2, 0 ou 3 e `NOMAD_PRESET` igual a 3 ou 0. Para a referência, use o mesmo script com a cena do commit `9a733a0` e `NOMAD_STAGE=antes`.
