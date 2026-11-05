/// One human-readable notebook shared by the playground and mounted rendering tests.
public enum FlatMarkRecipeSample {
    public static let markdown = [introduction, photo, dimpling, ingredients, bakeAlong, method, notes]
        .joined(separator: "\n\n")

    // Focused snapshots use these same sections, not a second set of sample Markdown.
    static let introduction = """
    # Sunday focaccia
    **Rosemary & olive oil** · One tray · Serves 6

    A crisp golden edge, a soft middle, and something worth sharing with @jane.doe and *@other*.
    ~~@third~~ will join next time; @ja*ne* is bringing olives.
    """

    static let photo = "[![Freshly baked focaccia — open the herb note](focaccia.jpeg)](herbs)"

    static let dimpling = """
    Once the dough is soft and airy, use your fingertips to make shallow dimples across the surface. Press a single <u>rosemary leaf</u> [![Rosemary leaf — open the herb note](leaf.png)](herbs) into each dimple, keeping the herbs tucked into the dough so they do not scorch. Finish with **a pinch of flaky salt** and a final drizzle of olive oil, then let the focaccia rest while the oven heats.

    <div>Print this recipe · Subscribe to the newsletter</div>
    """

    static let ingredients = """
    ## Ingredients
    - 500 g bread flour
    - 400 g lukewarm water
    - 7 g instant yeast and 10 g fine salt
    - 30 g olive oil, plus extra for the tin
    - 2 rosemary sprigs and a pinch of flaky salt
    """

    static let bakeAlong = """
    ## Bake along <u>with me</u>
    - [x] Weigh the ingredients with @jane_2
    - [ ] Mix the dough — **keep <u>the water</u> lukewarm**
      - [ ] Rest for 30 minutes
      - [x] Set out the olive oil
    - [ ] Oil the tin — [read the <u>tin note</u>](tin)
    - [ ] Dimple <u>gently</u> and scatter over the rosemary

    > Give the dough time to rise.
    >
    > > A cool kitchen needs <u>extra patience</u>; wait until the dough is soft and full of bubbles.\\
    > > Look for a gentle wobble when you shake the bowl.\\
    > > Keep the bowl covered so the surface does not dry out.\\
    > > Give it another half hour if the middle still feels tight.
    >
    > The dough is ready when the whole bowl looks lively, not just the edges.

    > > <div>Baker’s secret: a slow rise brings more flavour.</div>
    """

    static let method = """
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
       - Wet your fingertips before touching the dough.
         1. Lift gently without tearing the soft middle.
       - Let the dough settle back into the bowl.

       Turn the bowl between folds and keep the smooth side on top. The dough should feel stronger after each round.

       > Stop if the dough starts to tear; a short rest makes the next fold easier.

       ```text
       fold → turn → rest
       ```

    2. Turn the bowl and repeat on all four sides.

    Cool <u>before slicing</u>; the soft middle is worth the wait.\\
    Save a piece for tomorrow’s lunch.
    """

    static let notes = """
    ## Notes for the next bake
    Leave yourself a little inspiration<u></u> for next Sunday.

    ### Toppings
    Tuck the herbs into the dough, then add olives or thinly sliced onion.\\
    ![Rosemary leaf](leaf.png)\\
    Keep a few leaves for serving.

    #### Timing
    A longer rise gives the dough more flavour.

    ##### Overnight option
    Cover the bowl and leave it in the fridge.

    ###### Before baking
    Let the dough warm up before dimpling.

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
