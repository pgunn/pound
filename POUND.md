# Introduction #

POUND is an opensource Wiki/Blog engine written in mod\_perl and requiring a PostgreSQL backend. You can use either web interfaces or commandline tools to post/retrieve content.

# Installation #

Choose where the software will reside on your system, and configure Apache to load the mod\_perl module and assign whatever namespace you choose for POUND to the handler, which will then load the rest of the code appropriately. Install the database, tweaking the paths and permissions appropriately (familiarity with SQL helps a lot), then create accounts within POUND for your user and customise the posting scripts (if you intend to use them) to know about the PostgreSQL user/password you set up.