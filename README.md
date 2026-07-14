# BioScan 3D — Protótipo

Protótipo ponta a ponta de estimativa de composição corporal a partir de
geometria 3D do corpo. Reproduz a **metodologia** de dois produtos (não seus
coeficientes proprietários):

- **InBody-like** — análise segmentar por *soma de 5 segmentos* (braços, tronco,
  pernas). Em vez de impedância elétrica, o modelo é alimentado por volume e
  circunferência extraídos do mesh 3D (que o iPhone 17 captura com escala real
  via LiDAR/TrueDepth).
- **Shaped-like** — uma estimativa visual de % de gordura, fundida com o ramo
  geométrico para um resultado final mais estável.

> ⚠️ **Não é bioimpedância elétrica nem dispositivo médico.** Os coeficientes são
> ilustrativos e precisam ser re-ajustados contra DXA antes de qualquer uso real.

```
bioscan/
├── backend/        # API Python (FastAPI) — o "cálculo"
│   └── app/
│       ├── main.py         # endpoints
│       ├── schemas.py      # contratos de entrada/saída
│       ├── composition.py  # motor InBody-like + fusão Shaped-like
│       └── mesh.py         # extrai medidas de um mesh 3D (trimesh)
└── flutter_app/    # cliente Flutter multiplataforma (iOS/Android/web/desktop)
    └── lib/
        ├── main.dart          # tela de entrada + upload
        ├── api.dart           # cliente HTTP
        ├── models.dart        # modelos espelhando o backend
        └── result_screen.dart # relatório estilo InBody
```

## 1. Rodar o backend

```bash
cd backend
pip install -r requirements.txt        # use --break-system-packages se necessário
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Docs interativas em `http://127.0.0.1:8000/docs`.

### Endpoints
| Método | Rota | Descrição |
|---|---|---|
| GET | `/health` | Liveness |
| GET | `/v1/sample` | Payload de exemplo pronto para `/v1/compute` |
| POST | `/v1/compute` | Composição a partir de medidas + geometria dos 5 segmentos |
| POST | `/v1/compute-mesh` | Upload de mesh (OBJ/PLY/GLB/STL em cm) + antropometria básica |

### Teste rápido
```bash
curl -s localhost:8000/v1/sample | curl -s -X POST localhost:8000/v1/compute \
  -H 'Content-Type: application/json' -d @-
```

## 2. Rodar o app Flutter

```bash
cd flutter_app
flutter pub get
flutter run          # escolha o device: iOS, Android, Chrome, macOS, etc.
```

Ajuste a **URL do backend** na primeira tela:
- iOS simulator / desktop / web: `http://127.0.0.1:8000`
- **Android emulator**: `http://10.0.2.2:8000`
- **Device físico**: `http://<IP-da-sua-máquina>:8000` (mesma rede)

O app tem dois modos:
- **Modo A** — medidas simuladas (segmentos pré-preenchidos). Valida o cálculo rápido.
- **Modo B** — envia um mesh 3D. No app real, esse mesh viria do scan LiDAR/ARKit;
  aqui você escolhe um arquivo `.obj/.ply/.glb`.

## Como isto se encaixa no produto final

Este protótipo é o **núcleo de cálculo** (o "backend" pedido). No app de produção,
a captura no iPhone 17 (ARKit + LiDAR + TrueDepth) gera o mesh 3D escalonado, que
substitui a entrada de medidas/arquivo deste protótipo. Os módulos `composition.py`
e `mesh.py` permanecem praticamente iguais — muda apenas a origem dos dados.

## Próximos passos sugeridos
1. Re-ajustar os coeficientes de `composition.py` contra um dataset com DXA.
2. Trocar a extração de medidas por registro de template SMPL (fatias anatômicas consistentes).
3. Adicionar histórico/evolução (persistência) e o avatar 3D navegável.
4. Substituir o stub visual por um modelo real estilo Shaped.
