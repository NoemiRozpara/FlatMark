/// One human-readable notebook shared by the playground and mounted rendering tests.
public enum FlatMarkRecipeSample {
    public static let markdown = [introduction, photo, dimpling, ingredients, bakeAlong, method, notes]
        .joined(separator: "\n\n")

    // Sections preserve the complete recipe; fragments can also serve focused tests.
    static let introduction = [title, mentions].joined(separator: "\n\n")

    static let title = """
    # Sunday focaccia
    **Rosemary & olive oil** · One tray · Serves 6
    """

    static let mentions = """
    A crisp golden edge, a soft middle, and something worth sharing with @jane.doe and *@other*.
    ~~@third~~ will join next time; @ja*ne* is bringing olives.
    """

    static let photo = "[![Freshly baked focaccia — open the herb note](focaccia.jpeg)](herbs)"

    static let dimpling = [mixedInlineImage, promotionalHTML].joined(separator: "\n\n")

    static let mixedInlineImage = """
    Once the dough is soft and airy, use your fingertips to make shallow dimples across the surface. Press a single <u>rosemary leaf</u> [![Rosemary leaf — open the herb note](leaf.png)](herbs) into each dimple, keeping the herbs tucked into the dough so they do not scorch. Finish with **a pinch of flaky salt** and a final drizzle of olive oil, then let the focaccia rest while the oven heats.
    """

    static let promotionalHTML = """
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

    static let bakeAlong = [
        [bakeAlongHeading, taskRows].joined(separator: "\n"),
        nestedQuotes,
        secretQuote,
    ].joined(separator: "\n\n")

    static let bakeAlongHeading = "## Bake along <u>with me</u>"

    static let taskRows = """
    - [x] Weigh the ingredients with @jane_2
    - [ ] Mix the dough — **keep <u>the water</u> lukewarm**
      - [ ] Rest for 30 minutes
      - [x] Set out the olive oil
    - [ ] Oil the tin — [read the <u>tin note</u>](tin)
    - [ ] Dimple <u>gently</u> and scatter over the rosemary
    """

    static let nestedQuotes = """
    > Give the dough time to rise.
    >
    > > A cool kitchen needs <u>extra patience</u>; wait until the dough is soft and full of bubbles.\\
    > > Look for a gentle wobble when you shake the bowl.\\
    > > Keep the bowl covered so the surface does not dry out.\\
    > > Give it another half hour if the middle still feels tight.
    >
    > The dough is ready when the whole bowl looks lively, not just the edges.
    """

    static let secretQuote = """
    > > <div>Baker’s secret: a slow rise brings more flavour.</div>
    """

    static let method = [methodTable, thematicBreak, hydration, hydrationCode, nestedList, cooling]
        .joined(separator: "\n\n")

    static let methodTable = """
    | Stage | Time |
    | --- | --- |
    | Rise <u>until doubled</u> | 2–3 hours |
    | Bake | 25 min at 220°C — ask @jane |
    | Cool | <u>10 min before slicing</u> |
    """

    static let thematicBreak = "---"

    static let hydration = """
    This **80% hydration** dough feels sticky at first. Use `damp hands` for folding.
    """

    static let hydrationCode = """
    ```text
    water ÷ flour × 100 = hydration
    400 ÷ 500 × 100 = 80%
    ```
    """

    static let nestedList = """
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
    """

    static let cooling = """
    Cool <u>before slicing</u>; the soft middle is worth the wait.\\
    Save a piece for tomorrow’s lunch.
    """

    static let notes = [
        notesIntroduction, toppings, timingHeadings, emptyQuote, toppingTask, nextBakeList,
        contactNotes, mentionCode,
    ].joined(separator: "\n\n")

    static let notesIntroduction = """
    ## Notes for the next bake
    Leave yourself a little inspiration<u></u> for next Sunday.
    """

    static let toppings = ["### Toppings", hardBreakImage].joined(separator: "\n")

    static let hardBreakImage = """
    Tuck the herbs into the dough, then add olives or thinly sliced onion.\\
    ![Rosemary leaf](leaf.png)\\
    Keep a few leaves for serving.
    """

    static let timingHeadings = """
    #### Timing
    A longer rise gives the dough more flavour.

    ##### Overnight option
    Cover the bowl and leave it in the fridge.

    ###### Before baking
    Let the dough warm up before dimpling.
    """

    static let emptyQuote = "> > <u></u>"

    static let toppingTask = """
    - [ ] Record a topping idea

      > <u></u>

      > Add your favourite after tasting.
    """

    static let nextBakeList = """
    1. Save a slice to compare tomorrow.
    2. Try olives with @jane next Sunday.
    """

    static let contactNotes = """
    Send your baking notes to email@example.com (not a@jane), or read [@jane’s notes](folding).
    Label the tin `@jane`; labels and links keep their original styling.
    The clipped contact *email*@example.com keeps its original emphasis.
    """

    static let mentionCode = """
    ```text
    @jane: save a slice
    ```
    """
}
