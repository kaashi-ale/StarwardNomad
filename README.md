# Starward Nomad — Exploração Espacial 3D em Mundo Aberto (Godot 4.3+ / Android)

Jogo 3D single-player de exploração espacial e planetária desenvolvido em **Godot Engine 4.3+ (GDScript)** com foco em desempenho estável no **Motorola Moto G04s** (Android 14, Unisoc T606, Mali-G57 MP1, 4 GB RAM).

## Segunda entrega — planetas e voo

Abra `project.godot` no Godot 4.3 e pressione **F5**. Em **Qualidade**, ajuste **Volume do jogo** com os botões −/+ ou **Silenciar**. O volume, o estado silencioso e o perfil gráfico são salvos localmente. O perfil **Baixo** é o padrão. **Econômico** reduz a resolução interna e a densidade da vegetação.

### Teste de voo no PC

1. Pressione **E** ao lado da nave. Use **Tab** para escolher o destino e **F** para habilitar o curso assistido. O painel indica distância, desvio angular e condições de pouso.
2. Segure **W** para decolar e acelerar. O curso assistido orienta a nave, enquanto a aceleração continua sob seu controle. Use **A/D**, **↑/↓** ou arraste com o botão direito para pilotar. Uma intervenção na direção desliga o curso assistido.
3. Na aproximação, use **S** para frear e **Shift** para descer. **Espaço** sobe sem inclinar o nariz. Procure uma clareira em terra firme e pressione **E** quando o painel indicar **Pouso disponível**.

Os cinco mundos têm raios 3,5 vezes maiores. O relevo visível da órbita já mostra diferenças de altitude e cor. No solo, o HUD identifica o bioma. As copas, a densidade, os campos e as serras variam por planeta. Veridian Mire concentra a vegetação mais alta e fechada. Bosques boreais aparecem em Glacius IX e árvores de copa baixa crescem nos vales de Dusthaven. Animais, sentinelas e relés são gerados nas áreas próximas à exploração.

A geração de terreno detalhado começa na aproximação e distribui o trabalho entre quadros. No solo, o renderer pode omitir blocos atrás do horizonte. O traje usa menos chamadas de desenho e os sons sintetizados usam clipes em cache.

## Roteiro a pé — Aurelia Prime

Abra `project.godot` no Godot 4.3 e pressione **F5**. A cena principal é `Main.tscn`. Para comparar, importe o projeto da `main` no commit `498ecba` em outra pasta e rode F5 nos dois projetos com o mesmo perfil de qualidade.

- **Ponto de partida.** Você começa ao lado da nave, em uma planície acima da água. Caminhe na direção do pórtico, passe entre as colunas e pressione **E** junto ao relé para escaneá-lo. Criaturas pacíficas se afastam quando você chega perto.
- **Astronauta e câmera.** Ande com **WASD**, segure **Shift** para correr e arraste com o botão direito do mouse para mover a câmera. Toque **Espaço** para saltar e mantenha pressionado para acionar o jetpack no ar. Dispare com o botão esquerdo. A câmera encurta a distância junto à nave, ao pórtico e aos grandes rochedos.
- **Voo curto.** Volte à nave e pressione **E** para entrar. Use **Espaço** para decolar e **S** para frear. Perto do solo e em baixa velocidade, **E** solicita o pouso e desembarca assim que ele for aceito.

Para inspecionar a composição e a iluminação, abra `Main.tscn`. O traje é montado por `Player/ExplorerSuit.gd` na missão. A nave é montada por `Spaceship/SurveyCraft.gd`. O terreno, o pórtico e a vegetação são gerados em execução por `Planets/PlanetBody.gd` e `Planets/AureliaLanding.gd`, portanto rode a cena para vê-los.

Na segunda entrega, a amostra de perfil Baixo no Intel HD 2500 passou de **96 para 76 chamadas de desenho**, de **49,5 mil para 36 mil primitivas** e de aproximadamente **62 para 40 MiB** de memória estática contabilizada pelo Godot. O tempo mediano no ponto inicial ficou perto de **20 ms** nas duas versões. No Econômico, a mediana foi de **14,8 ms** e o percentil 95 caiu de **39,7 para 29,0 ms** em relação ao Baixo anterior. A medição cobre uma vista estática de Aurelia no PC, com 90 quadros por amostra, sem VSync nem limite de FPS.

A homologação desta etapa é no **PC**. No próximo APK, vale repetir o percurso com três dedos (joystick, câmera e disparo), depois correr e pular com o joystick ativo. A meta de 30 FPS no Moto G04s depende de medição no aparelho.

## Como Gerar o APK Android Sem Usar Computador (100% pelo Celular via GitHub Actions)

Este projeto já inclui o pipeline automatizado `.github/workflows/build_android_apk.yml` para compilar o `.apk` na nuvem gratuitamente usando apenas o navegador do seu celular:

1. No navegador do seu celular (Chrome), acesse [github.com](https://github.com) e crie um novo repositório (por exemplo, `starward-nomad`).
2. Extraia este ZIP no celular e envie os arquivos do projeto (incluindo a pasta oculta `.github/workflows/build_android_apk.yml`, `project.godot`, `export_presets.cfg` e todas as pastas) para o repositório.
3. Abra a aba **Actions** do repositório no GitHub e execute o workflow **Build Android APK (Zero-PC Cloud Build)**.
4. O servidor Linux do GitHub baixará automaticamente a Godot 4.3, os *Export Templates* oficiais, o Android SDK 34, criará o *keystore* de depuração e gerará **`StarwardNomad.apk`**.
5. Ao concluir (~2 minutos), toque no *Artifact* **`StarwardNomad-Android-APK`** na parte inferior da execução para baixar e instalar diretamente no Moto G04s.

## Controles e Regras de Voo / Pouso

### Mobile (Tela Sensível ao Toque)
- **Metade Esquerda da Tela:** Joystick virtual analógico (movimenta o explorador a pé ou direciona o nariz da nave em voo).
- **Metade Direita da Tela (fora dos botões):** Arraste o dedo para rotacionar a câmera 360° em torno do personagem.
- **A Pé:** `PULAR / JET` (salto + propulsor orbital), `CORRER` (alternância), `ATIRAR` (blaster de plasma), `ESCANEAR` (próximo a monólitos), `ENTRAR NA NAVE` (próximo à nave).
- **Na Nave:**
  - `ACELERAR` / `FREAR` / `SUBIR` / `DESCER`.
  - Toque em **DESTINO** para alternar sua seleção e **CURSO** para alinhar a nave.
  - Para pousar, aproxime-se a até **30 m** de uma área livre em terra firme e reduza a velocidade a **24 m/s** ou menos. Quando o botão **POUSAR NAVE** ficar verde, toque nele.
  - Após pousada, toque em **`SAIR DA NAVE`** para explorar o planeta a pé.

### Desktop (Teclado e Mouse para Testes Rápidos)
- `W A S D`: Mover a pé. Na nave, **W/S** aceleram ou freiam e **A/D** giram na horizontal.
- `↑/↓`: Inclinar o nariz da nave. `Tab` alterna o destino e `F` ativa ou desativa o curso assistido.
- `Espaço`: Pular / Jetpack / Subir nave
- `Shift`: Correr / Descer nave
- `Botão Direito do Mouse (segurar + mover)`: Rotacionar câmera
- `Botão Esquerdo do Mouse`: Atirar blaster
- `E`: Escanear, embarcar ou pousar e desembarcar, conforme o contexto
