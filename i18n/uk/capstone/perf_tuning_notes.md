# Performance tuning notes (capstone)

Використовуйте цей файл, щоб фіксувати тюнінг-експерименти як короткі, evidence-based звіти.

## Чому це важливо
Тюнінг має сенс лише тоді, коли ви можете довести:
- що проблема була реальною (baseline evidence)
- що зміна реально покращила ситуацію (result evidence)
- що ви розумієте ризики/регресії (що може стати гірше згодом)

Цей документ — ваш “paper trail” для PR рев’ю та для портфоліо.

## Workflow (рекомендовано)
1. Визначте мету (latency, CPU, logical reads, concurrency).
2. Зберіть baseline evidence (actual plan + IO/time).
3. Сформуйте гіпотезу (який оператор/стратегія дорога і чому).
4. Робіть одну зміну за раз (index, rewrite, statistics, predicate).
5. Зберіть result evidence (ті самі вхідні умови; actual plan + IO/time).
6. Зафіксуйте ризики та моніторинг (parameter sensitivity, ріст даних, skew).

## Чеклист доказів (evidence)
- Однакові умови для baseline і result (ті самі фільтри, той самий data window).
- Додайте `SET STATISTICS IO, TIME`.
- Додайте actual execution plan (не estimated).
- Поясніть зміну плану одним реченням (наприклад, “hash join → nested loops через новий індекс”).

## Рекомендований формат для експерименту
- Symptom:
- Hypothesis:
- Baseline evidence (actual plan + IO/time):
- Change made:
- Result evidence (actual plan + IO/time):
- Risks/regressions to watch:

## Типові anti-patterns
- Немає baseline (“відчувається швидше”).
- Кілька змін одночасно (не зрозуміло, що саме дало ефект).
- Додавання широких/дублюючих індексів без обґрунтування workload-ом.
- Тюнінг під одне значення параметра і регрес для інших (parameter sensitivity).

Порада: також можна використати шаблон [templates/tuning_report_template.md](../../../templates/tuning_report_template.md).
