# Dsl

I'm tired of gimped DSLs for managing cloud resources so I'm writing a proper one with the
help of Ruby's metaprogramming capabilities. No more gimped JSON DSLs for defining 
infrastructure and then trying to figure out how to shoehorn all the imperative parts of 
cloud orchestration into it. A properly designed library/DSL can provide all the necessary
components for performing both the declarative and imperative aspects of cloud resource
orchestration without placing undue restrictions on how you should structure the code
for doing so.

# Components

Towards that goal this library provides a basic DSL and the necessary objects for describing
a set of resources as a graph. You are allowed to even have cycles in that graph as long as
there is a way to break the cycle, e.g. AWS security groups. Since security group rules are
mutable it is possible to have a cycle because the security group can be created and then
the rules can be filled-in after the creation step (contrast with terraform that forces some
pretty interesting workarounds because they can not support mutable resource properties directly).

So the main components are the DSL context (used for defining the cloud resource graph), various
validators, a topological sorter (for proper resource creation sequencing), various matchers (for
querying the various backends to match up the components of the local graph with remote resource. 
Unlike terraform that requires state files you are allowed to write a custom matcher that caches
resources locally similar to terraform state files), various differs (for figuring out the difference
between the local graph and remote resources), various kinds of simulated and real backends (
for simulating the graph creation process to make sure things are mostly functional), and finally
some executors for carrying out the process of diffing, matching, and creating the resources in
the various backends.
