In recent years, LLMs have shown significant improvements in their overall performance. When they first became mainstream a couple of years before, they were already impressive with their seemingly human-like conversation abilities, but their reasoning always lacked. They were able to describe any sorting algorithm in the style of your favorite author; on the other hand, they weren't able to consistently perform addition. However, they improved significantly, and it's more and more difficult to find examples where they fail to reason. This created the belief that with enough scaling, LLMs will be able to learn general reasoning.

I wanted to test this claim with SAT problems. Why SAT? Because solving SAT problems require applying very few rules consistently. The principle stays the same even if you have millions of variables or just a couple. So if you know how to reason properly any SAT instances is solvable given enough time. Also, it's easy to generate completely random SAT problems that make it less likely for LLM to solve the problem based on pure pattern recognition. Therefore, I think it is a good problem type to test whether LLMs can generalize basic rules beyond their training data. 

## What is SAT?

SAT (short for "satisfiability") is a logic problem that given a boolean formula, it asks whether the boolean formula has an assignment that makes the problem `true`. An example boolean formula is:

```
(a || b) && !a
```

This formula is satisfiable because if we set to `b` to `true` and `a` to `false`, then the whole formula is `true`. All other assignments make the formula `false`, but it doesn't change that the formula is satisfiable as long as there is at least one assignment makes the formula `true`.

An unsatisfiable formula is:

```
b && !b
```

No matter what you assign to the `b`, it will be `false` since either the left or the right of the `&&` operator is `false`.

### CNF Form
There is a special form for boolean formulas called "Conjunctive Normal Form" (CNF). A problem in this form consists of clauses connected with and operators, where each clause only contains variables connected with or operators. The variables can appear negated, but only variables can be directly negated, something like `!(a && b)` is not allowed. An example boolean formula in CNF form is:

```
(a || b || c) &&
(!a || d || e) &&
(e || g || x)
```

SAT solvers usually expect boolean formulas in this form, because they are specialized to solve problems in this form efficiently. I decided to use this form to validate results of the LLM output with a SAT solver.

## Testing Approach

My approach is very simple:
1. Generate random SAT instances, both SAT and UNSAT.
2. Feed the SAT instance to the LLM.
3. Verify the output.

### Generating SAT problems

For the test to be fair for LLMs, the SAT instance should be reasonably large, but not too big. I can't just give SAT problems with thousands of variables since it would be too big. The problem should be not too small but also not too big. And it shouldn't be too easy.

I learned that for 4-SAT, if clause to variable ratio is more than 10, the generated problems become difficult to solve, and the likelihood of formula to be SAT or UNSAT is close to 50%. So I generated 3 types of formulas:
1. SAT problem with 10 variables and 200 clauses
2. SAT problem with 14 variables and 126 clauses
3. UNSAT problem with 10 variables and 200 clauses

I used [cnfgen](https://cnfgen.readthedocs.io/en/latest/) to generate SAT instances using the following command:

```
cnfgen -q randkcnf 4 $VARIABLES $CLAUSES
```

This command outputs the formula in [dimacs format](https://jix.github.io/varisat/manual/0.2.0/formats/dimacs.html), which is a standard format for CNF supported by every SAT solver.

### Models
I used https://openrouter.ai to test multiple models without having to register to different LLM providers.

I tested following models:
- Gemini 3 Pro
- GPT 5.2 Mini
- GPT 5.2

For each model reasoning was enabled, and the reasoning effort is set to high. I included GPT 5.2 because it could be argued that it can reason better than mini. However, I couldn't test GPT 5.2 as much as the other models because it was too costly. Gemini 3 Pro was costly as well, but it didn't spend as much time as GPT 5.2 during reasoning which made it more affordable in my experience.

For each model, I used the same system prompt:
```
The user will give a CNF in dimacs format.
Determine if it's satisfiable or not WITHOUT USING ANY EXTERNAL TOOLS.
Use your own reasoning. Don't stop even if the formula is too large just try to solve it manually.
After determining the result output a JSON with two fields:
    - satisfiable: Boolean. True if the formula is satisfiable
    - assignment: Array of booleans. If the formula is satisfiable provide an assignment for each variable from 1 to N. If the formula is not satisfiable this field is null.

EXAMPLE INPUT: 
p cnf 10 10
-7 9 10 0
7 8 9 0
-7 -9 10 0
-2 3 5 0
-4 -6 -8 0
-1 3 -5 0
1 -3 -8 0
4 -5 -10 0
4 -7 -8 0
-2 -5 8 0

EXAMPLE JSON OUTPUT:
{
	"satisfiable": true,
	"assignment": [false, false, false, false, false, false, false, false, false, false]
}
```

### Testing LLM Output
I used [z3](https://github.com/Z3Prover/z3) theorem prover to assess LLM output, which is a pretty decent SAT solver. I considered the LLM output successful if it determines the formula is SAT or UNSAT correctly, and for SAT case it needs to provide a valid assignment. Testing the assignment is easy, given an assignment you can add a single variable clause to the formula. If the resulting formula is still SAT, that means the assignment is valid otherwise it means that the assignment contradicts with the formula, and it is invalid.

Initially I aimed to test with at least 10 formulas for each model for SAT/UNSAT, but it turned out to be more expensive than I expected, so I tested ~5 formulas for each case/model. First, I used the openrouter API to automate the process, but I experienced response stops in the middle due to long reasoning process, so I reverted to using the chat interface (I don't if this was a problem from the model provider or if it's an openrouter issue). For this reason I don't have standard outputs for each testing, but I linked to the output for each case I mentioned in results.

## Results
All formulas used in this test can be found [here](https://github.com/onsah/llm-sat-testing/tree/main/formulas).

### Gemini 3 Pro
As a frontier flagship model, it was disappointing. It got no successful outcome. It seemed that it didn't reason thoroughly even though the reasoning was enabled, and the level set to high.

For SAT problems with 10 variables and 200 clauses, it usually output SAT as expected, but the assignment was never valid (Examples: [first](https://github.com/onsah/llm-sat-testing/blob/main/tests/gemini3pro/sat_10_200_1.txt), [second](https://github.com/onsah/llm-sat-testing/blob/main/tests/gemini3pro/sat_10_200_2.txt)). Once it claimed [a SAT formula was UNSAT](https://github.com/onsah/llm-sat-testing/blob/main/tests/gemini3pro/sat_10_200_3.txt). For this reason I didn't bother testing with more variables for the SAT case.

For UNSAT problems with 10 variables and 200 clauses, it always claimed that the formula is SAT and made up assignments (See [this example](https://github.com/onsah/llm-sat-testing/blob/main/tests/gemini3pro/unsat_10_200_1.json)).

### GPT 5.2 Mini
Surprisingly, as a smaller model it performed better than Gemini 3 Pro. It found some valid assignments for SAT formulas, but has the same issue of making up assignments for UNSAT formulas.

For SAT problems with 10 variables and 200 clauses, sometimes outputted UNSAT because it couldn't find any satisfying assignment, and it would take a lot more time to find one, which is logically sound. I don't consider this as bad reasoning as it is about performance. So I tried it with only 100 clauses and it [successfully found valid assignments](https://github.com/onsah/llm-sat-testing/blob/main/tests/gpt5.2-mini/sat/formula_10_100_1.json).

For UNSAT problems with 10 variables and 200 clauses, it had the same issue as Gemini 3 Pro of [making up assignments](https://github.com/onsah/llm-sat-testing/blob/main/tests/gpt5.2-mini/unsat/formula_10_100_1.json).

### GPT 5.2
This one was a lot better than others. For every SAT problem with 10 variables and 200 clauses it was able to find a [valid](https://github.com/onsah/llm-sat-testing/blob/main/tests/gpt5.2/sat/formula1.txt) [satisfying](https://github.com/onsah/llm-sat-testing/blob/main/tests/gpt5.2/sat/formula3.txt) [assignment](https://github.com/onsah/llm-sat-testing/blob/main/tests/gpt5.2/sat/formula4.txt). Therefore, I pushed it to test with 14 variables and 100 clauses, and it got half correct among 4 instances (See files with prefix `formula14_` in [here](https://github.com/onsah/llm-sat-testing/tree/main/tests/gpt5.2/sat)).

For UNSAT problems with 10 variables and 200 clauses it had the same issue as others: [making up assignments](https://github.com/onsah/llm-sat-testing/tree/main/tests/gpt5.2/unsat).

## Conclusion

I don't claim that my findings are authoritative in any way. I tested with way too few formulas to make any claims about how random LLM output is. But I think it is sufficent to show that current LLMs don't consistently reason. There is a recent [research](https://arxiv.org/abs/2505.14615) that did a thorough testing with models such as GPT-4o, and found that for hard enough problems, every model degrades to random guessing. It would be nice to see this testing done again with newer models.

I am not very knowledgeable about LLMs, but my gut feeling is that LLMs don't seem to be able to generalize logical rules such that it can solve a class of problem with 100% of accuracy. However, their statistical strength got so much better that it's way harder to find a case where they start to break down. I don't imply anything else such as LLMs being useful or not. They can be definitely useful without being able to reason, but lack of reasoning tells me that using LLMs unsupervised can be very dangerous as we can't trust them to apply logical rules consistently. Of course in reality it makes more sense to offload as much as reasoning to external tools that are specifically designed for the problem, but as long as LLMs are doing the orchestration itself, they will always be responsible for determining how to delegate tasks to other tools, which needs proper reasoning.

