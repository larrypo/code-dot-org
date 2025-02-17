import PropTypes from 'prop-types';
import React, {Component} from 'react';
import {Table, sort} from 'reactabular';
import {tableLayoutStyles, sortableOptions} from '../tables/tableConstants';
import {freeResponsesDataPropType} from './assessmentDataShapes';
import i18n from '@cdo/locale';
import wrappedSortable from '../tables/wrapped_sortable';
import orderBy from 'lodash/orderBy';
import color from '@cdo/apps/util/color';

const PADDING = 15;

const styles = {
  studentNameColumnHeader: {
    padding: PADDING
  },
  studentNameColumnCell: {
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    maxWidth: 200,
    padding: PADDING,
    verticalAlign: 'top'
  },
  responseColumnHeader: {
    padding: PADDING
  },
  noResponse: {
    color: color.lighter_gray
  }
};

export const COLUMNS = {
  NAME: 0,
  RESPONSE: 1
};

class FreeResponsesAssessmentsTable extends Component {
  static propTypes = {
    freeResponses: PropTypes.arrayOf(freeResponsesDataPropType)
  };

  state = {
    [COLUMNS.NAME]: {
      direction: 'desc',
      position: 0
    }
  };

  getSortingColumns = () => {
    return this.state.sortingColumns || {};
  };

  onSort = selectedColumn => {
    this.setState({
      sortingColumns: sort.byColumn({
        sortingColumns: this.state.sortingColumns,
        sortingOrder: {
          FIRST: 'asc',
          asc: 'desc',
          desc: 'asc'
        },
        selectedColumn
      })
    });
  };

  responseCellFormatter = (response, {rowData, rowIndex}) => {
    return (
      <div>
        {response && <div>{response}</div>}
        {!response && (
          <div style={styles.noResponse}>{i18n.emptyFreeResponse()}</div>
        )}
      </div>
    );
  };

  getColumns = (sortable, index) => {
    let dataColumns = [
      {
        property: 'name',
        header: {
          label: i18n.studentName(),
          props: {
            style: {
              ...tableLayoutStyles.headerCell,
              ...styles.studentNameColumnHeader
            }
          }
        },
        cell: {
          props: {
            style: {
              ...tableLayoutStyles.cell,
              ...styles.studentNameColumnCell
            }
          }
        }
      },
      {
        property: 'response',
        header: {
          label: i18n.response(),
          props: {
            style: {
              ...tableLayoutStyles.headerCell,
              ...styles.responseHeaderCell
            }
          }
        },
        cell: {
          format: this.responseCellFormatter,
          props: {style: tableLayoutStyles.cell}
        }
      }
    ];
    return dataColumns;
  };

  render() {
    // Define a sorting transform that can be applied to each column
    const sortable = wrappedSortable(
      this.getSortingColumns,
      this.onSort,
      sortableOptions
    );
    const columns = this.getColumns(sortable);
    const sortingColumns = this.getSortingColumns();

    const sortedRows = sort.sorter({
      columns,
      sortingColumns,
      sort: orderBy
    })(this.props.freeResponses);

    return (
      <Table.Provider columns={columns} style={tableLayoutStyles.table}>
        <Table.Header />
        <Table.Body rows={sortedRows} rowKey="id" />
      </Table.Provider>
    );
  }
}

export default FreeResponsesAssessmentsTable;
