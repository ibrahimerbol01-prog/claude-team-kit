# claude-team-kit

Набор для команды, в которой несколько человек одновременно работают с Claude над одним
GitHub-репозиторием: хакатоны, учебные проекты, небольшие стартапы. Рассчитан на 6 человек,
у каждого свой Claude Pro. Один владелец сливает в `main`. Ключи в репозитории не хранятся.

Каждый Claude читает одни и те же правила, работает в своей ветке и своей зоне и сдаёт
работу через PR. Так шесть Claude не пишут поверх друг друга.

## Что внутри

| Файл в проекте | Зачем |
| --- | --- |
| `CLAUDE.md` | Правила для всех Claude: задача → ветка → PR, запреты, зоны, экономия лимитов |
| `.github/team.conf` | Владелец, участники и их роли, команда проверок |
| `scripts/team.sh` | Запуск на `gh`: `task`, `start`, `sync`, `pr`, `note`, `board`, `merge`, `setup`, `doctor` |
| `.github/CODEOWNERS` | Владелец ревьюит всё, зоны ролей — по желанию |
| `.github/pull_request_template.md` | Шаблон PR с `Closes #` и чек-листом |
| `.github/ISSUE_TEMPLATE/` | Формы «Задача» и «Ошибка» |
| `.github/workflows/team-checks.yml` | На каждый PR: gitleaks, нет `.env`, имя ветки, `Closes #` |
| `.claude/settings.json` | Claude не читает `.env*`, не пушит в `main`, не сливает PR |
| `.claude/skills/team-task/` | Навык участника: взять задачу и довести до PR |
| `.claude/skills/team-lead/` | Навык владельца: задачи, доска, разбор и слияние PR, финал |
| `docs/team/ROLES.md` | Шесть ролей и их зоны |
| `docs/team/PROMPTS.md` | Старт-промпты для каждого случая |
| `docs/team/HACKATHON.md` | Расписание на 24 и 48 часов, сценарий демо, питч |
| `docs/team/RELAY.md` | Почта между Claude: один диктует задания, другой выполняет и шлёт файлы |

## Установка (владелец, 10 минут)

Нужны `git`, [GitHub CLI](https://cli.github.com) (`gh auth login`), для объединения
настроек — `jq`.

```bash
git clone https://github.com/ibrahimerbol01-prog/claude-team-kit
cd ваш-проект && git switch -c lead/0-team-kit
../claude-team-kit/install.sh . --dry-run   # посмотреть, что изменится
../claude-team-kit/install.sh .
```

Установщик ничего не перезаписывает: существующий `CLAUDE.md` дополняет блоком правил,
`.gitignore` — строками `.env*`, `.claude/settings.json` объединяет. Остальные уже
существующие файлы пропускает (заменить — `--force`). Владельца берёт из `gh` или из
адреса `origin`, команду проверок — из `package.json`.

Потом:

1. Впишите участников в `.github/team.conf`, зоны — в `CODEOWNERS` и `docs/team/ROLES.md`,
   раздел «Проект» — в `CLAUDE.md`.
2. Закоммитьте, откройте PR, слейте в `main`.
3. `scripts/team.sh setup` — метки, защита `main`, удаление веток после слияния.
4. Пригласите участников: Settings → Collaborators, роль Write.
5. Ключи раздайте лично (менеджер паролей, личные сообщения). Каждый кладёт их в свой
   `.env.local`, который git не видит.

> Защита ветки на приватном репозитории требует платного тарифа GitHub. Без неё правило
> «сливает только владелец» держится на `CLAUDE.md`, настройках Claude и проверках PR.

## Участнику (5 минут)

```bash
gh auth login
gh repo clone ВЛАДЕЛЕЦ/ПРОЕКТ && cd ПРОЕКТ
scripts/team.sh doctor
claude          # первым сообщением — «Первый запуск» из docs/team/PROMPTS.md
```

Дальше цикл: `scripts/team.sh start 12` → работа с Claude → `scripts/team.sh pr`.

## Шпаргалка

```
scripts/team.sh board                       доска
scripts/team.sh task "Экран квиза" frontend новая задача
scripts/team.sh start 12                    взять задачу #12
scripts/team.sh sync                        подтянуть main
scripts/team.sh pr                          проверки + PR
scripts/team.sh note 12 "что дальше"        передать работу
scripts/team.sh merge 34                    (владелец) слить PR #34
```

Любую команду можно запустить с `--dry-run`, чтобы увидеть, что она сделает.

## Почта между Claude

Один Claude может диктовать задания другому и обмениваться с ним файлами через ветку
`team-relay` (в `main` она не попадает):

```
scripts/team.sh send друг "Экран квиза" задание.md данные.json   # диспетчер
scripts/team.sh inbox --wait=15                                    # исполнитель ждёт письмо
scripts/team.sh reply ID "Готово" Quiz.tsx                         # исполнитель отвечает
```

Подробно и со старт-промптами для обоих — `docs/team/RELAY.md`.

## Навыки из Everything Claude Code

По желанию к набору можно добавить навыки из [affaan-m/ECC](https://github.com/affaan-m/ECC)
(MIT). Для командной работы полезны `team-agent-orchestration`, `parallel-execution-optimizer`,
`git-workflow`, `github-ops`, `issue-review`, `security-review`. Ставьте плагин целиком
(`/plugin marketplace add https://github.com/affaan-m/ECC`, `/plugin install ecc@ecc`),
выключив хуки (`hooks_enabled: false`), чтобы у всех шестерых Claude вёл себя одинаково.

## Лицензия

MIT
