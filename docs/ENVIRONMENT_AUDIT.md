# Reconstrução ambiental global

A comparação usa a versão publicada `282ae258`, com a mesma árvore Git da base local `cada7b3`. As duas rodadas rodaram no Godot 4.3 Compatibility com as configurações de projeto da branch. [Antes](screenshots/reconstrucao-global/antes/) · [Depois](screenshots/reconstrucao-global/depois/) · [Locais](screenshots/reconstrucao-global/LOCAIS.txt)

## Terreno e ambiente

- `PlanetLandscape.gd` combina campos contínuos de continente, cadeias, colinas, umidade e textura local. Cada mundo compõe esses campos com pesos e curvas próprios. Os biomas combinam umidade, altitude, latitude, costa e inclinação. Em Aurelia, o terreno autoral permanece até 145 m da chegada, com transição até 275 m. O relevo do Vale do Trevo usa uma plataforma tangente com borda suavizada.
- `PlanetTerrainMesh.gd` amostra a cube-sphere em 65 × 65 vértices por face. `PlanetBody.gd` divide a malha de desenho em 96 patches com culling por horizonte e um segundo índice de LOD para os interiores. O contorno do patch conserva os vértices completos nos dois níveis. As bordas entre faces compartilham a função contínua de normais. O colisor de resolução cheia fica fixo durante as trocas de LOD. A esfera orbital é uma malha separada com o mesmo amostrador.
- O oceano usa as mesmas direções e triângulos do terreno, com profundidade interpolada e água opaca. Aurelia tem águas azuis e verdes e uma faixa de areia, Glacius tem água fria e superfície de gelo estilizada, e Veridian tem margens verdes e lamacentas. A nave continua recusando pouso abaixo do nível d’água.
- `SurfaceLife.gd` usa setores determinísticos, pré-carregamento até 280 m na direção da velocidade tangencial, geração de um setor a cada três quadros de física e descarte com sobreposição temporal. A distância pondera altura e separação horizontal. A quantidade visível por MultiMesh diminui progressivamente com a distância. Econômico usa copas compactas, enquanto os outros perfis mostram o modelo de origem de perto. Os perfis ajustam os lotes existentes. As colisões de troncos e rochas principais só ficam ativas perto do jogador e acompanham as instâncias visíveis. A floresta, a trilha e a vila construídas têm uma área reservada.
- `PlanetLandmark.gd` posiciona uma formação determinística por planeta com acesso, colisores simples e um relé escaneável. Os centros dos marcos e as capturas usam coordenadas locais independentes do sistema de origem flutuante. O ponto de instalação usa um raio no colisor final.

| Mundo | Relevo e vegetação | Marco |
| --- | --- | --- |
| Aurelia Prime | Costas, vales, serras, pradarias e dois tipos de copa Quaternius, arbustos, samambaias, flores, gramíneas e rochas musgosas | Lapa dos Ventos, passagem sob rocha |
| Pyros V | Cinzas, cânions, cristas, rochas Quaternius em tons de basalto e vegetação residual | Dentes de Basalto |
| Glacius IX | Cordilheiras, vales glaciais, tundra, margens geladas e pinheiros boreais esparsos | Agulhas de Geada |
| Veridian Mire | Várzeas, terraços úmidos, copas altas, samambaias e neblina verde | Raízes da Várzea |
| Dusthaven | Dunas, mesetas, rochas estratificadas quentes e vegetação rara | Janela das Mesetas, passagem rochosa |

O inventário identifica os modelos, materiais e licenças. A flor de campo e a rocha estratificada vieram do ZIP Standard já disponível e reutilizam os atlases instalados. [Inventário](../Assets/Environment/INVENTARIO.md)

## Procedimento e limites

As capturas usam uma câmera de auditoria sem HUD, com a mesma direção radial, altura relativa ao chão, guinada e inclinação em cada par. O relevo pode mudar a altitude absoluta ou o bioma do ponto. Os arquivos WebP guardam a saída real do renderizador redimensionada para 960 px. A comparação começa no perfil Econômico. Os perfis são alternados somente na etapa de troca gráfica. O coletor limita o registro a amostras curtas e inclui estatísticas de memória estática do Godot, que não representam a RAM total do processo nem a VRAM.

Os scripts em `docs/tools/` podem ser chamados por caminho absoluto com `godot --path . --script`. A pasta de documentação é ignorada na importação e exportação. Para reproduzir as capturas, informe `NOMAD_STAGE=antes` na versão de referência e `NOMAD_STAGE=depois` na versão atual. `NOMAD_AUDIT_MODE=extras` renderiza os marcos e vistas adicionais. `NOMAD_AUDIT_MODE=motion` mede as sequências de movimento. Use o mesmo `NOMAD_AUDIT_DIR` nas duas versões.

A base usa um colisor planetário completo por mundo próximo e dois níveis de desenho na superfície. Permanecem visíveis transições entre o proxy orbital e os patches, além de mudanças na quantidade de instâncias nas faixas de distância. A água representa mares, baixios e margens ao nível oceânico. Os marcos são formações abertas e relés. Rios, cachoeiras, cavernas subterrâneas e lagos independentes ficaram de fora. A campanha de testes cobre trajetos curtos e não mede vazamentos em sessões longas.

## Desempenho no PC

Intel Celeron 1007U, Mesa Intel HD Graphics 2500, 7,4 GiB de RAM, janela de 1120 × 630, VSync e limite de FPS desligados. Cada cenário rodou por 144 quadros reais depois de 50 quadros de estabilização. Caminhada e voo usam entradas do jogo. O voo rápido nesta tabela é atmosférico. O cruzeiro acima de 500 m/s foi verificado separadamente no teste funcional. O número fixo de quadros permite durações e distâncias diferentes. Valores indicam antes → depois.

| Cenário | FPS médio | Quadro médio (ms) | p95 (ms) | Maior quadro (ms) | Setores ao final |
| --- | ---: | ---: | ---: | ---: | ---: |
| Vila parado | 59,7 → 57,4 | 16,7 → 17,4 | 21,5 → 23,1 | 29,8 → 55,8 | 9 → 11 |
| Caminhada floresta | 106,3 → 87,3 | 9,4 → 11,4 | 16,1 → 15,9 | 28,8 → 36,7 | 9 → 14 |
| Caminhada campo | 113,0 → 133,6 | 8,9 → 7,5 | 14,5 → 11,7 | 31,3 → 31,8 | 9 → 17 |
| Caminhada serra | 95,6 → 114,7 | 10,5 → 8,7 | 21,5 → 12,5 | 45,4 → 32,8 | 9 → 10 |
| Voo baixo | 70,6 → 65,3 | 14,2 → 15,3 | 40,6 → 32,4 | 67,9 → 86,6 | 9 → 20 |
| Voo rapido | 93,6 → 97,0 | 10,7 → 10,3 | 27,2 → 26,6 | 39,6 → 46,0 | 9 → 27 |
| Aproximacao | 87,8 → 79,1 | 11,4 → 12,6 | 28,2 → 32,6 | 32,8 → 78,9 | 9 → 0 |
| Desembarque | 71,4 → 60,2 | 14,0 → 16,6 | 20,3 → 28,0 | 110,9 → 93,1 | 9 → 13 |
| Perfis graficos | 13,7 → 17,3 | 72,8 → 57,7 | 48,6 → 113,6 | 4251,3 → 920,3 | 9 → 21 |
| Pyros | 77,1 → 116,7 | 13,0 → 8,6 | 25,0 → 16,0 | 64,0 → 50,0 | 9 → 14 |
| Glacius | 81,5 → 165,2 | 12,3 → 6,1 | 22,2 → 10,8 | 40,7 → 25,4 | 9 → 10 |
| Veridian | 100,9 → 130,4 | 9,9 → 7,7 | 19,3 → 15,6 | 52,8 → 29,2 | 9 → 14 |
| Dusthaven | 51,6 → 111,0 | 19,4 → 9,0 | 39,0 → 15,5 | 86,3 → 19,4 | 9 → 15 |

O voo baixo teve p95 menor e mais chamadas de desenho. A aproximação orbital, o desembarque e a permanência na vila continuaram com custo maior nesta rodada. A maior pausa na primeira passagem por todos os perfis caiu de 4,25 s para 0,92 s. O p95 dessa etapa subiu, indicando que Alto ainda pesa. A memória estática no final dos cinco destinos caiu de 67,7 para 59,2 MiB na última amostra em Dusthaven. Ao fim do voo atmosférico rápido a nova versão reteve 27 setores, abaixo do limite de 30 no Econômico. As imagens registram o resultado visual obtido antes do ajuste final do limite do cache.

As amostras completas incluem deslocamento, memória alocada, chamadas de desenho e triângulos. As contagens de instâncias cobrem os lotes regionais carregados e excluem a vegetação da vila. [Medições brutas](screenshots/reconstrucao-global/MEDICOES.csv)

## Verificação funcional

- Cena principal importada e executada no Godot 4.3 Compatibility. As rodadas gráficas não registraram erros de scripts ou shaders. O renderizador dummy dos testes headless ainda registra avisos de recursos descartados na saída.
- Percurso da nave à vila a pé pelo arco, nos perfis Econômico e Baixo. Conferidos os colisores do arco, de casa e de árvore, conversa com Lina, presença de três moradores e duas vaquinhas, caminhada, salto, jetpack, disparo com movimento e câmera simultâneos por eventos de toque simulados, embarque, desembarque e retorno da nave por chamada.
- Decolagem, voo baixo, saída da atmosfera, cruzeiro acima de 500 m/s e aproximação de Pyros com curso assistido, em uma viagem sem reposicionar a nave. Os outros destinos usaram reposicionamento do teste para repetir pouso manual, desembarque e caminhada. Cada planeta recebeu 96 raios radiais de colisão atravessando direções de borda, um teste de colisão do marco e troca dos quatro perfis. Em Aurelia, Glacius e Veridian, os raios confirmaram terreno acima e abaixo do nível do mar.
- A verificação de toque no PC injeta eventos do Godot. No Moto G04s ainda é preciso validar toque físico, fluidez, temperatura, memória e pouso ou chamada passando pela costa. Use como referência as medidas anteriores relatadas na vila: Econômico 30 FPS, Baixo 25–30 FPS e Alto 7–15 FPS. Essas medidas pertencem à versão anterior.
