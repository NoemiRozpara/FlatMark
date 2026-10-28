/// One human-readable notebook shared by the playground and mounted rendering tests.
public enum FlatMarkRecipeSample {
    public static let markdown = """
    # Sunday focaccia
    **Rosemary & olive oil** · One tray · Serves 6

    A crisp golden edge, a soft middle, and something worth sharing with @jane.doe and *@other*.
    ~~@third~~ will join next time; @ja*ne* is bringing olives.

    [![Freshly baked focaccia — open the herb note](focaccia.png)](herbs)

    <div>Print this recipe · Subscribe to the newsletter</div>

    ## Ingredients
    - 500 g bread flour
    - 400 g lukewarm water
    - 7 g instant yeast and 10 g fine salt
    - 30 g olive oil, plus extra for the tin
    - 2 rosemary sprigs and a pinch of flaky salt

    ## Bake along <u>with me</u>
    - [x] Weigh the ingredients with @jane_2
    - [ ] Mix the dough — **keep <u>the water</u> lukewarm**
      - [ ] Rest for 30 minutes
      - [x] Set out the olive oil
    - [ ] Oil the tin — [read the <u>tin note</u>](tin)
    - [ ] Dimple <u>gently</u> and scatter over the rosemary

    > Give the dough time to rise.
    >
    > > A cool kitchen needs <u>extra patience</u>.

    > > <div>Baker’s secret: a slow rise brings more flavour.</div>

    | Stage | Time |
    | --- | --- |
    | Rise <u>until doubled</u> | 2–3 hours |
    | Bake | 25 min at 220°C — ask @jane |
    | Cool | <u>10 min before slicing</u> |

    ---

    This **80% hydration** dough feels sticky at first. Use `damp hands` for folding.

    ```text
    water ÷ flour × 100 = hydration
    400 ÷ 500 × 100 = 80%
    ```

    1. Lift an edge and fold it into the middle.
    2. Turn the bowl and repeat on all four sides.

    Cool <u>before slicing</u>; the soft middle is worth the wait.\\
    Save a piece for tomorrow’s lunch.

    ## Notes for the next bake
    Leave yourself a little inspiration for next Sunday.

    > > <u></u>

    - [ ] Record a topping idea

      > <u></u>

      > Add your favourite after tasting.

    1. Save a slice to compare tomorrow.
    2. Try olives with @jane next Sunday.

    Send your baking notes to email@example.com (not a@jane), or read [@jane’s notes](folding).
    Label the tin `@jane`; labels and links keep their original styling.
    The clipped contact *email*@example.com keeps its original emphasis.

    ```text
    @jane: save a slice
    ```
    """
}
