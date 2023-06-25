/* eslint-disable */
// this is an auto generated file. This will be overwritten

export const createBudget = /* GraphQL */ `
  mutation CreateBudget(
    $input: CreateBudgetInput!
    $condition: ModelBudgetConditionInput
  ) {
    createBudget(input: $input, condition: $condition) {
      id
      total
      createdAt
      updatedAt
      _version
      _deleted
      _lastChangedAt
      __typename
    }
  }
`;
export const updateBudget = /* GraphQL */ `
  mutation UpdateBudget(
    $input: UpdateBudgetInput!
    $condition: ModelBudgetConditionInput
  ) {
    updateBudget(input: $input, condition: $condition) {
      id
      total
      createdAt
      updatedAt
      _version
      _deleted
      _lastChangedAt
      __typename
    }
  }
`;
export const deleteBudget = /* GraphQL */ `
  mutation DeleteBudget(
    $input: DeleteBudgetInput!
    $condition: ModelBudgetConditionInput
  ) {
    deleteBudget(input: $input, condition: $condition) {
      id
      total
      createdAt
      updatedAt
      _version
      _deleted
      _lastChangedAt
      __typename
    }
  }
`;
export const createTransaction = /* GraphQL */ `
  mutation CreateTransaction(
    $input: CreateTransactionInput!
    $condition: ModelTransactionConditionInput
  ) {
    createTransaction(input: $input, condition: $condition) {
      id
      amount
      type
      category
      createdAt
      updatedAt
      _version
      _deleted
      _lastChangedAt
      __typename
    }
  }
`;
export const updateTransaction = /* GraphQL */ `
  mutation UpdateTransaction(
    $input: UpdateTransactionInput!
    $condition: ModelTransactionConditionInput
  ) {
    updateTransaction(input: $input, condition: $condition) {
      id
      amount
      type
      category
      createdAt
      updatedAt
      _version
      _deleted
      _lastChangedAt
      __typename
    }
  }
`;
export const deleteTransaction = /* GraphQL */ `
  mutation DeleteTransaction(
    $input: DeleteTransactionInput!
    $condition: ModelTransactionConditionInput
  ) {
    deleteTransaction(input: $input, condition: $condition) {
      id
      amount
      type
      category
      createdAt
      updatedAt
      _version
      _deleted
      _lastChangedAt
      __typename
    }
  }
`;
