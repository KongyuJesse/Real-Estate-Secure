# Cameroon Property Sales Compliance

This note translates the current Cameroon real-estate sale procedure into
platform rules. It separates statutory steps from platform policy so the system
does not overstate what the law requires.

## Current Legal Baseline

As of March 18, 2026, the core land and title framework still rests on the
1974-1976 regime, while MINDCAF reform work remains in consultation and
roadmap form rather than a complete enacted replacement.

Primary sources reviewed:

- MINDCAF documentation portal:
  `https://www.mindcaf.gov.cm/fr/docs/`
- MINDCAF user guide and procedure matrix:
  `https://www.mindcaf.gov.cm/media/filer_public/6a/cb/6acb60c5-4852-48a4-be8a-d806aca2c0a2/matrice_des_procedures.pdf`
- MINDCAF procedure for foreign access to land:
  `https://www.mindcaf.gov.cm/media/filer_public/a1/ad/a1ada938-b8c6-4a81-ac4c-5a9348c2df5c/procedure_dacces_a_la_terre_au_cameroun_pour_les_etrangers.pdf`
- Law No. 80-21 amending article 10 of Ordinance No. 74-1:
  `https://fpae-cameroun.org/oatge/legislation/loi-n80-21-du-14-juillet-1980-modifiant-et-completant-certaines-dispositions-de-lordonnance-n74-1-du-6-juillet-1974-fixant-le-regime-foncier/`
- Decree No. 76/165 on obtaining land title:
  `https://juriafrica.com/lex/decret-76-165-27-avril-1976-16710.htm`

## What Is Statutory for a Standard Sale

For a titled property sale, the platform treats the following as the core state
process:

- recent certificate of property
- municipal urbanism certificate
- municipal accessibility certificate
- sale deed executed before a notary
- registration of the deed
- mutation of title at the land registry

These requirements are reflected in the official MINDCAF user workflow for
`mutation totale du titre foncier`.

## Additional Documents the Platform Requires

The platform requires more than the legal minimum because fraud prevention is a
product promise, not just a registry promise. For production-grade onboarding,
due diligence, and payout authorization, the platform should collect:

- seller and buyer identity records
- land title copy
- survey plan
- tax clearance or fiscal conformity evidence where applicable
- non-encumbrance evidence when the file indicates debt or prior charge
- signed site plan or equivalent parcel reference
- power of attorney if a representative signs
- RCCM, NIU, and board authority for corporate parties
- succession records for inherited property
- judgment and no-appeal evidence for contentious transfers
- external payment evidence for off-platform or hybrid settlements
- stamped filing receipts, hearing notices, clerk-issued documents, certified
  judgment copies, ministerial non-objection, commission minutes, and
  cadastral signed plans when the file leaves the ordinary lane

## Foreign Buyers or Sellers

Article 10 as amended by Law No. 80-21 makes foreign-party real-estate
acquisition subject to special control. The MINDCAF foreign-access procedure
and visa dossier should be treated as mandatory when a foreign individual or
entity is involved.

Platform effect:

- `foreign_party_involved = true`
- MINDCAF prior authorization and visa become required
- lawyer review becomes required
- notary step remains required for a sale
- closing cannot complete until the foreign-party dossier is attached

## Lawyer vs Notary

The platform must distinguish the two roles.

**Notary**

- For a standard property sale, the notary is part of the ordinary legal path.
- The platform treats notarial closing as required for sales.

**Lawyer**

- A lawyer is not treated as universally mandatory for every ordinary domestic
  sale.
- This is an inference from the official MINDCAF sale procedure, which centers
  the parties, the notary, municipal certificates, tax registration, and land
  registry mutation, rather than listing counsel as a mandatory actor.
- The platform still makes lawyer review required for higher-risk cases.

Lawyer required by platform policy for:

- foreign-party transactions
- succession or estate sales
- corporate-party transactions
- use of power of attorney
- encumbered property
- judgment-driven or disputed files
- off-platform or hybrid settlement
- administrative appeals or administrative litigation
- justice execution, domain national, and old-title regularization files

Lawyer recommended, but not automatically required, for:

- standard domestic titled sale with no visible complexity flags
- long lease files that are not contentious

Lawyer usually not required by platform policy for:

- basic rentals with clean identity and no legal incident

## Revenue Model Without Transaction Fees

The platform should not depend on a percentage of sale price. In the Cameroon
market, that raises trust friction and pushes users off-platform. Revenue
should come from products tied to operational value instead:

- subscriptions for agencies, developers, and active sellers
- featured listing boosts
- property verification bundles
- document vault subscriptions
- foreign-buyer compliance packs
- lawyer and notary lead-matching
- premium advertising slots
- developer workspace subscriptions

This is modeled in the database with `platform_service_catalog` and
`service_orders`, while legacy transaction-fee columns are left only for
backward compatibility and default to zero.

## Role Tasking Rules

Each role should receive concrete next actions instead of passive records.

Buyer:

- fund escrow or declare external settlement
- assign lawyer when required
- assign notary for sale closing
- complete inspection or dispute decision

Seller:

- complete core property documents
- track verification status
- coordinate lawyer and notary assignment on active deals

Lawyer:

- review pending property and transaction documents
- review settlement declarations
- issue legal review decisions on complex files

Notary:

- prepare deed execution
- coordinate registration and title-mutation evidence

Admin:

- dispatch KYC review backlog
- dispatch paid service orders
- monitor compliance exceptions
- supervise frozen assisted files and legal cases that require admin oversight

## Offline and Court-Linked Procedure Rule

The platform now explicitly models physical and quasi-contentious procedures
instead of keeping them as free-form notes.

When a file depends on court, ministry, commission, cadastral, or other
physical-office action, the backend can create:

- `transaction_offline_steps`
  For notary-office, municipal, tax, MINDCAF, court, justice-execution,
  commission, and cadastral follow-up.
- `transaction_legal_cases`
  For administrative appeals, administrative litigation, justice execution,
  succession, judgment-enforcement, domain national allocation, old-title
  regularization, and foreign-party authorization.

These records support:

- explicit expected office and next follow-up date
- delay reason tracking
- original-seen and certified-copy evidence metadata
- `automation_frozen` transaction state while court or ministry blockers remain
  unresolved

## Implementation Summary

The backend and database now encode this policy through:

- `notary_profiles`
- transaction legal case type and requirement levels
- transaction compliance payloads
- zero-default platform transaction fees
- paid service catalog and order records
- offline physical workflow tables and legal-case workflow tables
- role-based task feeds for buyers, sellers, lawyers, notaries, and admins
