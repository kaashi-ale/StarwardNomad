# Guia de Auditoria Técnica (v0.2.0 — Pós-Correções)

Este documento descreve a arquitetura, correções aplicadas após a auditoria estática de 18/11/2026 e limitações conhecidas do projeto **Starward Nomad**.

## 1. Correções Aplicadas Nesta Revisão (v0.2.0)
- **CRÍTICO-1 (`Space/SpaceSystem.gd`):** Instanciação direta via `PlanetBody.new()` removendo `StaticBody3D.new()` + `set_script()`, eliminando o erro de análise estática em `planet.initialize()`.
- **CRÍTICO-2 (`Planets/PlanetBody.gd`):** Ordem dos índices de triângulos corrigida para sentido horário (`(i0, i2, i1)` e `(i1, i2, i3)`) conforme convenção de faces frontais da Godot 4, garantindo visibilidade externa e colisão unilateral `ConcavePolygonShape3D` corretas.
- **ALTO-1 (`project.godot`):** Adicionado `pointing/emulate_mouse_from_touch=false` em `[input_devices]` para impedir disparo contínuo acidental do blaster ao tocar na tela Android.
- **ALTO-2 (`Space/SpaceSystem.gd`):** Inicialização escalonada de planetas (`_build_planets_staggered`): o planeta inicial (*Aurelia Prime*) é construído imediatamente no frame 1 e os 4 planetas seguintes são gerados 1 por frame (`await get_tree().process_frame`), prevenindo travamento/ANR no Moto G04s.
- **ALTO-3 (`Planets/PlanetBody.gd`):** Implementado LOD de 2 níveis (`TerrainMesh` detalhado próximo vs. `DistantProxyMesh` esférico de ~384 triângulos em espaço profundo) e culling por distância para `OceanSphere` e `AtmosphereHalo`, reduzindo overdraw na GPU Mali-G57 MP1.
- **ALTO-4 (`Spaceship/Spaceship.gd`):** Regra de velocidade máxima de pouso (`<= 55 m/s`) aplicada também em `try_land_ship()`, alinhando física, indicador visual do HUD e documentação.
- **MÉDIO-1 & MÉDIO-2 (`Main.gd` e `Spaceship/Spaceship.gd`):** Consulta explícita à altura do relevo (`get_surface_point_and_normal`) no ponto exato de spawn e desembarque do jogador.
- **MÉDIO-4 (`Player/Player.gd`):** Tratamento dedicado para microgravidade (`has_gravity = false`) fora das atmosferas planetárias em vez de queda arbitrária em `-Y`.
- **MÉDIO-5 (`Planets/PlanetBody.gd`):** Indexação da malha procedural via `st.index()` antes de `st.generate_normals()`.
- **BAIXO-1, BAIXO-2, BAIXO-4, BAIXO-5:** Contagem exata documentada (`6.534 quads` / `13.068 triângulos` por planeta), aplicação imediata de sombras via `QualityManager.refresh_scene_settings()` em `Main.gd`, exclusão dos botões de ação da área de arrasto de câmera no `TouchHUD.gd` e atualização de marcadores/atmosfera a 20 Hz.

## 2. Invariantes Estruturais Verificadas
- **Renderer:** `gl_compatibility` configurado para Desktop e Mobile (`rendering/renderer/rendering_method.mobile="gl_compatibility"`).
- **Autoloads (`project.godot`):** `GameState` (`res://Systems/GameState.gd`) e `QualityManager` (`res://Systems/QualityManager.gd`).
- **Malha Planetária:** 6 faces × 33 × 33 quads = **6.534 quads (13.068 triângulos)** por planeta, indexados.
- **Pipeline CI/CD Mobile:** `.github/workflows/build_android_apk.yml` incluído para compilação automatizada do APK sem computador local.

## 3. Limitações Conhecidas
1. **Não executado no binário Godot neste ambiente:** Toda validação foi realizada por análise estática, verificação matemática de vetores/normais e verificação automatizada de referências e cenas.
2. **Modelos 3D e Áudio:** Visuais compostos por primitivos nativos da Godot (`CapsuleMesh`, `PrismMesh`, `TorusMesh`, `ArrayMesh`) e áudio sintetizado em tempo real via `AudioStreamGenerator` para zero dependência de assets binários.
3. **Persistência:** Descobertas ficam em memória na sessão atual (`GameState.discovered_sites`).
