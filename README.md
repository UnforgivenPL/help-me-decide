# help-me-decide
Some code for narrowing down a wide range of options based on certain criteria. More of a fun exercise than a Real Thing, but who knows?

## how does it work?

What is needed are:
* a dataset connecting things with features;
* a series of choices.

### the setup

First, you need **things**. It does not matter what those things are, as long as each of them has an id that distinguishes one thing from another. A good example is a set of pizzas available in a restaurant.

Then you need **features**: a definition of uniquely named and typed features each thing has. For a pizza (any pizza) this would be: toppings (chosen from a predefined set of options), size, price, how spicy it is, what type of dough it is on, etc.

Finally, you need **a dataset** that maps things with features. This would mean that our pizzeria offers, among others, "Margherita XL" with 3 toppings (mozzarella, sauce and fresh basil) and 40 cm in diameter.

### the selection

Once a dataset with bazillion things is ready, you can start answering **questions**. Each **answer** narrows the selection down to a manageable size and the process continues until there are either no more questions to ask, or the number of available things matching the criteria is manageable.

Questions are selected based on two things:
* a **strategy** - for example, whether to ask random questions, or ones that reduce the dataset the most, and the like;
* previous answers - obviously, this is needed to avoid asking the same question twice.

## how to use it?

### the core

Main code is written in Ruby and is nothing more than a set of modules and objects that implement the logic of selection.

### the api

A REST API backed by Sinatra is provided for other applications. The data format used is YAML (JSON is also fine, as each JSON document is a YAML document).   

## License

All code is released under Apache License. Originally written by Miki of Unforgiven.pl.

Code is hosted on GitHub. Feel free to suggest issues, report bugs and contribute to the development. Thank you!
