# Starward Nomad — Exploração Espacial 3D em Mundo Aberto (Godot 4.3+ / Android)

Jogo 3D single-player de exploração espacial e planetária desenvolvido em **Godot Engine 4.3+ (GDScript)** com foco em desempenho estável no **Motorola Moto G04s** (Android 14, Unisoc T606, Mali-G57 MP1, 4 GB RAM).

## Primeira entrega — Aurelia Prime

Abra `project.godot` no Godot 4.3 e pressione **F5**. A cena principal é `Main.tscn`. Para comparar, importe o projeto da `main` no commit `498ecba` em outra pasta e rode F5 nos dois projetos com o mesmo perfil de qualidade.

- **Ponto de partida.** Você começa ao lado da nave, em uma planície acima da água. Caminhe na direção do pórtico, passe entre as colunas e pressione **E** junto ao relé para escaneá-lo. As duas criaturas da área se afastam quando você chega perto.
- **Astronauta e câmera.** Ande com **WASD**, segure **Shift** para correr e arraste com o botão direito do mouse para mover a câmera. Toque **Espaço** para saltar e mantenha pressionado para acionar o jetpack no ar. Dispare com o botão esquerdo. A câmera encurta a distância junto à nave, ao pórtico e aos grandes rochedos.
- **Voo curto.** Volte à nave e pressione **E** para entrar. Use **Espaço** para decolar e **S** para frear. Perto do solo e em baixa velocidade, **E** solicita o pouso e desembarca assim que ele for aceito.

Para inspecionar a composição e a iluminação, abra `Main.tscn`. O traje é montado por `Player/ExplorerSuit.gd` na missão. A nave é montada por `Spaceship/SurveyCraft.gd`. O terreno, o pórtico e a vegetação são gerados em execução por `Planets/PlanetBody.gd` e `Planets/AureliaLanding.gd`, portanto rode a cena para vê-los.

No Godot 4.3 com OpenGL Compatibility (Intel HD 2500), amostras estáticas do ponto inicial registraram **18 FPS e 159 chamadas de desenho no Médio** e **29 FPS e 94 chamadas no Leve**. O contador de memória estática do Godot ficou em torno de **62 MiB** nos dois perfis. São amostras de um quadro no PC. O perfil Leve mantém a iluminação e desativa sombras em tempo real. A versão anterior registrou 22 FPS no Médio, com erros repetidos de rotação de fauna.

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
  - Durante o voo atmosférico, a nave mantém margem mínima de segurança de `2,2 m` acima do relevo para evitar colisões subterrâneas acidentais.
  - Para pousar, aproxime-se a menos de `42 m` do solo e reduza a velocidade para `<= 55 m/s` (o botão `POUSAR NAVE` ficará verde) e toque em **`POUSAR NAVE`**.
  - Após pousada, toque em **`SAIR DA NAVE`** para explorar o planeta a pé.

### Desktop (Teclado e Mouse para Testes Rápidos)
- `W A S D`: Mover / Direcionar nave
- `Espaço`: Pular / Jetpack / Subir nave
- `Shift`: Correr / Descer nave
- `Botão Direito do Mouse (segurar + mover)`: Rotacionar câmera
- `Botão Esquerdo do Mouse`: Atirar blaster
- `E`: Escanear, embarcar ou pousar e desembarcar, conforme o contexto
