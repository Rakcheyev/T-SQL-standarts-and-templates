**Мова:** [English](../../BEN_GAN_CANON.md) | Українська

# “Канон” (Ben‑Gan як стиль патернів) — як використовувати безпечно

Ця сторінка — **список посилань + гайд для навчання** для тих, хто хоче глибше зануритись у “класичний” стиль T‑SQL патернів (Itzik Ben‑Gan та суміжні матеріали SQL Server).

**Важливе правило:** використовуйте ці джерела лише як *натхнення*. Не копіюйте текст у цей репозиторій. Натомість діставайте **патерни**, а пояснення й labs робіть оригінальними.

## Для чого це

Найбільш корисні (high ROI) напрями, де “класичні” матеріали часто найсильніші:

- **Set-based мислення:** менше циклів/“по рядку”, більше операцій над множинами.
- **Коректність на edge cases:** NULL семантика, дублікати, ties, детермінований порядок.
- **Патерни віконних функцій:** дедуплікація, послідовності, накопичувальні суми, gaps-and-islands.
- **Table expressions:** derived tables vs CTEs vs APPLY і коли що допомагає.

## Як працювати з джерелами етично (і ефективно)

Практичний процес, який не заводить у копіювання:

1. Прочитайте опис патерна в джерелі.
2. Закрийте джерело.
3. Опишіть ідею **своїми словами** з пам’яті.
4. Зберіть **свіжий датасет** (ваші назви таблиць + ваші значення).
5. Додайте:
   - чітке формулювання задачі,
   - “першу спробу” (часто помилкову),
   - правильне рішення,
   - пояснення, *чому* воно коректне,
   - вправу, яка змушує пройти через tie/NULL/duplicate.

Якщо не можете пояснити патерн без підглядання — значить, він ще не засвоєний.

## Надійні стартові точки

- Microsoft Press Store (пошук / список книг):
  - https://www.microsoftpressstore.com/search/index.aspx?query=Ben-Gan
- T‑SQL Fundamentals (4th Edition):
  - https://www.microsoftpressstore.com/store/t-sql-fundamentals-9780138102104
- T‑SQL Window Functions (2nd Edition):
  - https://www.microsoftpressstore.com/store/t-sql-window-functions-for-data-analysis-and-beyond-9780135861448
- T‑SQL Querying:
  - https://www.microsoftpressstore.com/store/t-sql-querying-9780735685048

Історичне (але досі корисне для мислення):

- Архів MSDN Magazine (APPLY / CTE / PIVOT/UNPIVOT / TRY/CATCH / SNAPSHOT):
  - https://learn.microsoft.com/en-us/archive/msdn-magazine/2004/february/powerful-t-sql-syntax-gives-sql-server-a-programmability-boost

## Рекомендований шлях у цьому репозиторії

- Віконні функції:
  - Урок 6 (вступ): `course/lessons/06_data_chas_vikonni_funkcii.md`
  - Урок 7B (поглиблено): `course/lessons/07b_window_functions_deep_dive.md`
- Table expressions + APPLY:
  - Урок 7 (розділ про APPLY): `course/lessons/07_advanced_query_patterns.md`
  - Елективний lab pack: `course/lessons/17_table_expressions_lab_pack.md`

## Який результат вважати “хорошим”

Коли додаєте новий патерн/лаб у репозиторій, націлюйтесь на:

- чіткий опис **grain** (що означає 1 рядок)
- хоча б один **контрприклад датасету** (ties, NULL, дублікати)
- детермінований `ORDER BY` там, де це важливо
- маленький, перевірюваний expected output
- коротку нотатку: tradeoffs коректність vs продуктивність vs підтримуваність
