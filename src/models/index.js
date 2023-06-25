// @ts-check
import { initSchema } from '@aws-amplify/datastore';
import { schema } from './schema';

const TransactionType = {
  "EXPENSE": "EXPENSE",
  "INCOME": "INCOME"
};

const { Budget, Transaction } = initSchema(schema);

export {
  Budget,
  Transaction,
  TransactionType
};