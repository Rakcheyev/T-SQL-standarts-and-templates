**Мова:** [English](../../README.md) | Українська

# T-SQL-standarts-and-templates

Колекція навчальних матеріалів і прикладів для роботи з **SQL** (у темах уроків зустрічаються як загальні конструкції SQL, так і специфічні можливості окремих СУБД).

## Як користуватися курсом

- Рекомендований маршрут читання: [LEARNING_PATH.md](LEARNING_PATH.md)
- Довідковий покажчик тем і підзаголовків: [navigation.md](navigation.md)
- Детальний індекс за заголовками: [navigation_detailed.md](navigation_detailed.md)
- Окрема інструкція для тих, хто вчиться: [README__for_learners.md](README__for_learners.md)

Навчальні матеріали розміщені у [course/lessons/](course/lessons/).

## Структура репозиторію

- Уроки: [course/lessons/](course/lessons/)
- Ілюстрації до уроків: [assets/images/](../../assets/images/)
- Допоміжні скрипти для обробки Markdown: [scripts/](../../scripts/)
- Архів/резервні файли: [archive/](../../archive/) та [backups/](../../backups/)

## Про локальні артефакти

- Папка `.venv/` (локальне Python-середовище) не є частиною навчальних матеріалів і не повинна зберігатися в репозиторії; вона додана до `.gitignore`.
- Тимчасові файли на кшталт `*.md.bak` також ігноруються (див. `.gitignore`).

## Підтримка

Щоб згенерувати індекси навігації та виконати швидку sanity-перевірку відповідності EN/UK уроків:

- `powershell -ExecutionPolicy Bypass -File .\\scripts\\verify_repo.ps1`

Щоб запустити лише перевірки без перегенерації навігації:

- `powershell -ExecutionPolicy Bypass -File .\\scripts\\verify_repo.ps1 -SkipNavigation`
